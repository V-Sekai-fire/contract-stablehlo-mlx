import Std.Data.HashMap
import StablehloMlx.Ast
import StablehloMlx.Kernels.Run

/-!
# `StablehloMlx.Lower` — the op table: each StableHLO op as MLX calls

`run` walks a function's ops in order and binds each result to an MLX array.
Nothing is evaluated here: MLX builds a lazy graph, and `Exec` either evaluates
it or traces it once under `mx::compile`.

Exactness, op by op (each checked by `Tests/OpTests.lean`):
* data movement and IEEE single-rounding arithmetic (`add`, `subtract`,
  `multiply`, `negate`, `abs`, `maximum`, compares, `select`, bit ops, reshape,
  transpose, broadcast, slice, concatenate, convert between integer and binary32,
  bitcast) are MLX built-ins: each output is one correctly rounded operation, so
  any order gives the same bits.
* `divide` and `sqrt` on binary32 go to the exact kernels (`f32_div`,
  `f32_sqrt`): a GPU's own `/` and `sqrt` need not be correctly rounded.
* `dot_general` is ggml-cpu's `ggml_vec_dot_f32` order (the `mul_mat` kernel).
* `composite` ops named, and `custom_call` ops targeting, `ggml.norm`,
  `ggml.soft_max`, `ggml.silu` and `ggml.gelu_erf` run ggml-cpu's routine (the
  kernels of the same names); any other composite runs its decomposition.
  Their binary32 attributes (`eps`, `scale`) are hex bit patterns
  (`0x3727C5AC : f32`), in `composite_attributes` or `backend_config`.

The generic form that `contract-ggml-stablehlo` emits (every ggml op spelled
out in StableHLO, in ggml-cpu's order) also needs:
* `f64` arithmetic (`add`, `subtract`, `multiply`, `divide`, `floor`, and
  `convert` to and from `f32` and to `i64`) — the GPU has no binary64, so an
  `f64` tensor is a `uint64` array of bit patterns and each op is the soft-float
  kernel `f64_ew` (`f64_of_f32`, `f32_of_f64`); `compare`, `maximum`, `abs`
  and `negate` on `f64` are integer operations on the bit patterns;
* `while` with a trip count known when the module is traced: the loop is
  unrolled into the MLX graph. Scalar integers made of constants (and sums,
  products, compares and converts of them) are tracked for that, and for the
  start indices of `dynamic_slice`, which becomes a static slice. A loop or a
  slice that depends on data is refused;
* `gather` of a 1-D table (`take`, indices clamped as StableHLO clamps them)
  and `reduce` with a `maximum` body.
Regions see the values of the enclosing block, as MLIR regions do.

`Faults` selects a planted wrong lowering per op, so each test can show that
it detects the wrong answer.
-/

namespace StablehloMlx.Lower

open StablehloMlx.Mlx
open StablehloMlx.Kernels

/-- Planted wrong lowerings, all off in normal use. -/
structure Faults where
  dotBuiltin : Bool := false     -- MLX's own matmul for dot_general
  dotPlain : Bool := false       -- a sequential binary32 sum without FMA
  softMaxFloatSum : Bool := false
  normGpuOps : Bool := false
  siluGpuOps : Bool := false
  geluTanh : Bool := false
  divideBuiltin : Bool := false
  sqrtBuiltin : Bool := false
  binaryHalf : Bool := false        -- elementwise arithmetic carried out in float16
  broadcastFirst : Bool := false    -- broadcast_in_dim of the operand's first element only
  concatSwap : Bool := false        -- concatenate with the operands in reverse order
  transposeIdentity : Bool := false -- transpose as a reshape (no permutation)
  sliceShift : Bool := false        -- slice starting one element late on the last axis
  f64AsF32 : Bool := false          -- binary64 arithmetic carried out in binary32
  whileShort : Bool := false        -- a while loop's last iteration dropped
  deriving Inhabited

abbrev Env := Std.HashMap String Arr

def err (msg : String) : IO α := throw (IO.userError msg)

def get (env : Env) (n : String) : IO Arr :=
  match env[n]? with
  | some a => pure a
  | none => err s!"undefined value {n}"

/-! ## Attribute text -/

/-- The integers in `array<i64: 1, 2>`, `[1, 2]`, or `dense<[1, 2]> : …`. -/
def ints (s : String) : Array Nat :=
  let body := match s.splitOn ":" with
    | _ :: rest@(_ :: _) => if s.startsWith "array<" then ":".intercalate rest else s
    -- `array<i64>` is empty: its only digits are the element type's width.
    | _ => if s.startsWith "array<" then "" else s
  let toks := body.split (fun c => !(c.isDigit)) |>.toList |>.map (·.toString) |>.filter (!·.isEmpty)
  toks.toArray.map String.toNat!

/-- The value of `key = …` inside a `#stablehlo.dot<…>`-style text. -/
def field (s key : String) : String :=
  match s.splitOn (key ++ " = ") with
  | _ :: rest :: _ => (rest.splitOn "]").head! ++ "]"
  | _ => ""

def elDtype (el : String) : IO UInt8 :=
  match el with
  | "f32" => pure dtF32
  | "i32" | "si32" => pure dtI32
  | "ui32" => pure dtU32
  | "i64" | "si64" => pure dtI64
  | "ui64" => pure dtU64
  | "i1" => pure dtBool
  | "ui8" => pure dtU8
  | "f64" => pure dtU64   -- binary64 travels as its bit pattern
  | e => err s!"element type {e} is not carried"

def elBytes (el : String) : Nat :=
  if el == "f64" || el == "i64" || el == "ui64" || el == "si64" then 8 else if el == "i1" || el == "ui8" then 1 else 4

/-- Parse one literal of a `dense<…>` attribute into its bit pattern. -/
def literalBits (el lit : String) : IO Nat := do
  let t := lit.trimAscii.toString
  if t == "true" then return 1
  if t == "false" then return 0
  if t.startsWith "0x" || t.startsWith "0X" then
    return (t.drop 2).foldl (fun n c => n * 16 + (if c.isDigit then c.toNat - '0'.toNat
      else (c.toLower.toNat - 'a'.toNat + 10))) 0
  if el.startsWith "f" then
    err s!"decimal float literal {t} for {el}: write it as a hex bit pattern so it is exact"
  let neg := t.startsWith "-"
  let mag := (if neg then t.drop 1 else t.toSlice).toString.toNat!
  let w := 8 * elBytes el
  return if neg then 2 ^ w - mag else mag

def bytesOf (el : String) (bits : Array Nat) : ByteArray := Id.run do
  let w := elBytes el
  let mut b := ByteArray.emptyWithCapacity (w * bits.size)
  for x in bits do
    for k in List.range w do b := b.push ((x >>> (8 * k)) % 256).toUInt8
  return b

def constant (o : Op) : IO Arr := do
  let some v := o.attr? "value" | err "constant without value"
  let t := o.outTys[0]!
  let inner := ((v.splitOn "dense<").getD 1 "").splitOn ">" |>.head!
  let inner := inner.replace "[" "" |>.replace "]" ""
  let lits := (inner.splitOn ",").filter (!·.trimAscii.isEmpty)
  let bits ← lits.toArray.mapM (literalBits t.el)
  let dt ← elDtype t.el
  if bits.size == 1 && t.count != 1 then
    let s ← ofBytes (bytesOf t.el bits) #[] dt
    broadcast s t.dims
  else
    if bits.size != t.count then err s!"constant has {bits.size} values for {t.str}"
    ofBytes (bytesOf t.el bits) t.dims dt

/-- The f32 bit pattern of `key = 0x… : f32` in a composite's attributes. -/
def f32Attr (attrs key : String) : IO UInt32 := do
  match attrs.splitOn (key ++ " = ") with
  | _ :: rest :: _ => return (← literalBits "f32" ((rest.splitOn " ").head!)).toUInt32
  | _ => err s!"composite attribute {key} missing"

/-! ## dot_general -/

def dotGeneral (f : Faults) (o : Op) (a b : Arr) : IO Arr := do
  let dn := (o.attr? "dot_dimension_numbers").getD ""
  let lb := ints (field dn "lhs_batching_dimensions")
  let rb := ints (field dn "rhs_batching_dimensions")
  let lc := ints (field dn "lhs_contracting_dimensions")
  let rc := ints (field dn "rhs_contracting_dimensions")
  let ta := o.inTys[0]!
  let tb := o.inTys[1]!
  if lc.size != 1 || rc.size != 1 then err "dot_general: one contracting dimension is carried"
  let lf := (List.range ta.dims.size).toArray.filter fun d => !(lb.contains d) && !(lc.contains d)
  let rf := (List.range tb.dims.size).toArray.filter fun d => !(rb.contains d) && !(rc.contains d)
  let prod (t : Ty) (ds : Array Nat) := ds.foldl (fun n d => n * t.dims[d]!) 1
  let B := prod ta lb
  let N := prod ta lf
  let M := prod tb rf
  let K := ta.dims[lc[0]!]!
  -- Operands to [batch, free, contract], contiguous.
  let a2 ← reshape (← transpose a (lb ++ lf ++ lc)) #[B * N, K]
  let b2 ← reshape (← transpose b (rb ++ rf ++ rc)) #[B * M, K]
  let out := o.outTys[0]!
  if f.dotBuiltin then
    let a3 ← reshape a2 #[B, N, K]
    let b3 ← transpose (← reshape b2 #[B, M, K]) #[0, 2, 1]
    return ← reshape (← binary opMatmul a3 b3) out.dims
  let y ← Run.mulMat b2 a2 K M (B * N) N (if B > 1 then M * K else 0) f.dotPlain
  reshape y out.dims

/-! ## The table -/

def unaryCode : String → Option UInt32
  | "stablehlo.negate" => some opNeg
  | "stablehlo.abs" => some opAbs
  | "stablehlo.floor" => some opFloor
  | "stablehlo.not" => some opInvert
  | "stablehlo.exponential" => some opExp
  | "stablehlo.tanh" => some opTanh
  | "stablehlo.logistic" => some opSigmoid
  | _ => none

def binaryCode : String → Option UInt32
  | "stablehlo.add" => some opAdd
  | "stablehlo.subtract" => some opSub
  | "stablehlo.multiply" => some opMul
  | "stablehlo.maximum" => some opMax
  | "stablehlo.minimum" => some opMin
  | "stablehlo.and" => some opAnd
  | "stablehlo.or" => some opOr
  | "stablehlo.xor" => some opXor
  | "stablehlo.shift_left" => some opShl
  | "stablehlo.shift_right_logical" => some opShr
  | "stablehlo.remainder" => some opRem
  | _ => none

/-- The direction of a `compare`: `EQ` from `#stablehlo<comparison_direction EQ>`. -/
def direction (o : Op) : String :=
  let t := (o.attr? "comparison_direction").getD ""
  ((t.splitOn "comparison_direction ").getLast!.replace ">" "").trimAscii.toString

def compareCode (dir : String) : IO UInt32 :=
  if dir.endsWith "EQ" then pure opEq else if dir.endsWith "NE" then pure opNe
  else if dir.endsWith "LT" then pure opLt else if dir.endsWith "LE" then pure opLe
  else if dir.endsWith "GT" then pure opGt else if dir.endsWith "GE" then pure opGe
  else err s!"comparison {dir}"

/-! ## Scalars known at trace time -/

abbrev Known := Std.HashMap String Int

def isIntEl (el : String) : Bool :=
  ["i1", "i8", "ui8", "i32", "si32", "ui32", "i64", "si64", "ui64"].contains el

/-- The value of a scalar integer that is a constant, or arithmetic on such
    scalars: what `while` conditions and `dynamic_slice` starts are made of. -/
def constEval (known : Known) (o : Op) : Option Int := do
  let out ← o.outTys[0]?
  if out.dims.size != 0 || !isIntEl out.el then none
  let k (i : Nat) : Option Int := o.operands[i]? >>= known.get?
  match o.name with
  | "stablehlo.constant" =>
    let v ← o.attr? "value"
    let t := (((v.splitOn "dense<").getD 1 "").splitOn ">").head!.trimAscii.toString
    if t == "true" then some 1 else if t == "false" then some 0 else t.toInt?
  | "stablehlo.add" => return (← k 0) + (← k 1)
  | "stablehlo.subtract" => return (← k 0) - (← k 1)
  | "stablehlo.multiply" => return (← k 0) * (← k 1)
  | "stablehlo.convert" => k 0
  | "stablehlo.compare" =>
    let a ← k 0
    let b ← k 1
    let dir := direction o
    let r := if dir.endsWith "EQ" then a == b else if dir.endsWith "NE" then a != b
      else if dir.endsWith "LT" then a < b else if dir.endsWith "LE" then a ≤ b
      else if dir.endsWith "GT" then a > b else a ≥ b
    return if r then 1 else 0
  | _ => none

/-! ## binary64 as uint64 bit patterns -/

def ABS64 : UInt64 := 0x7FFFFFFFFFFFFFFF
def INF64 : UInt64 := 0x7FF0000000000000
def SIGN64 : UInt64 := 0x8000000000000000
def QUIET64 : UInt64 := 0x0008000000000000

def f64Ew (op : Nat) (a b : Arr) (t : Ty) : IO Arr := do
  reshape (← Run.f64Ew op (← reshape a #[t.count]) (← reshape b #[t.count]) t.count) t.dims

def f64Nan (x : Arr) : IO Arr := do
  binary opGt (← binary opAnd x (← u64Scalar ABS64)) (← u64Scalar INF64)

def f64Zero (x : Arr) : IO Arr := do
  binary opEq (← binary opAnd x (← u64Scalar ABS64)) (← u64Scalar 0)

/-- A uint64 key whose unsigned order is the numeric order (−0 just below +0). -/
def f64Key (x : Arr) : IO Arr := do
  let neg ← binary opMul (← binary opShr x (← u64Scalar 63)) (← u64Scalar 0xFFFFFFFFFFFFFFFF)
  binary opXor x (← binary opOr neg (← u64Scalar SIGN64))

/-- IEEE comparison of binary64 bit patterns: unordered (a NaN) is false for
    every direction but NE, and −0 equals +0. -/
def f64Compare (dir : String) (a b : Arr) : IO Arr := do
  let ordered ← binary opLAnd (← unary opNot (← f64Nan a)) (← unary opNot (← f64Nan b))
  let zeros ← binary opLAnd (← f64Zero a) (← f64Zero b)
  let ka ← f64Key a
  let kb ← f64Key b
  let eq ← binary opLAnd ordered (← binary opLOr (← binary opEq a b) zeros)
  let lt ← binary opLAnd ordered (← binary opLAnd (← unary opNot zeros) (← binary opLt ka kb))
  let gt ← binary opLAnd ordered (← binary opLAnd (← unary opNot zeros) (← binary opGt ka kb))
  if dir.endsWith "EQ" then return eq
  if dir.endsWith "NE" then return ← unary opNot eq
  if dir.endsWith "LT" then return lt
  if dir.endsWith "LE" then return ← binary opLOr lt eq
  if dir.endsWith "GT" then return gt
  if dir.endsWith "GE" then return ← binary opLOr gt eq
  err s!"comparison {dir}"

/-- `maximum` / `minimum` on binary64: a NaN operand gives that NaN quieted
    (arm64 `fmax`), else the larger (smaller), with +0 above −0. -/
def f64MaxMin (isMax : Bool) (a b : Arr) : IO Arr := do
  let q (x : Arr) : IO Arr := do binary opOr x (← u64Scalar QUIET64)
  let pick ← binary (if isMax then opGe else opLe) (← f64Key a) (← f64Key b)
  let r ← where_ pick a b
  where_ (← f64Nan a) (← q a) (← where_ (← f64Nan b) (← q b) r)

/-- The rows-and-columns view ggml's row ops take: the last dimension is a row. -/
def rowsCols (t : Ty) : Nat × Nat :=
  let c := t.dims.back?.getD 1
  (t.count / max c 1, c)

/-- `convert`, by source and target element type. -/
def convertOp (a : Arr) (src out : Ty) : IO Arr := do
  match src.el, out.el with
  | "f32", "f64" => reshape (← Run.f64OfF32 (← reshape a #[out.count]) out.count) out.dims
  | "f64", "f32" => reshape (← Run.f32OfF64 (← reshape a #[out.count]) out.count) out.dims
  | "f64", "f64" => pure a
  | "f64", e =>
    if e == "i64" || e == "si64" then f64Ew Run.f64ToI64 a a out
    else err s!"convert f64 to {e} is not carried"
  | s, "f64" => err s!"convert {s} to f64 is not carried"
  | _, e => astype a (← elDtype e)

/-- `stablehlo.gather` of a 1-D table: `out[i] = table[clamp(idx[i])]`, the form
    `contract-ggml-stablehlo` emits (`gather1d`). Any other form is refused. -/
def gather1d (o : Op) (table idx : Arr) : IO Arr := do
  let dn := (o.attr? "dimension_numbers").getD ""
  let t := o.inTys[0]!
  let it := o.inTys[1]!
  unless t.dims.size == 1 && (field dn "collapsed_slice_dims") == "[0]" && (field dn "start_index_map") == "[0]"
      && (dn.splitOn s!"index_vector_dim = {it.dims.size}").length > 1
      && ints ((o.attr? "slice_sizes").getD "") == #[1] do
    err s!"gather: only a 1-D table indexed elementwise is carried ({dn})"
  let ix ← astype idx dtI64
  let lo ← astype (← u32Arr #[0]) dtI64
  let hi ← astype (← u32Arr #[(t.dims[0]! - 1).toUInt32]) dtI64
  let ix ← binary opMin (← binary opMax ix (← reshape lo #[])) (← reshape hi #[])
  take table ix 0

mutual
  partial def runOp (m : Module) (f : Faults) (env : Env) (known : Known) (o : Op) : IO (Array Arr) := do
    let args ← o.operands.mapM (get env)
    let out := o.outTys[0]?.getD default
    let n := o.name
    let el0 := (o.inTys[0]?.map (·.el)).getD ""
    -- binary64 arithmetic and comparisons: soft float on the bit patterns.
    if el0 == "f64" && f.f64AsF32 then
      let narrow (a : Arr) : IO Arr := convertOp a { out with el := "f64" } { out with el := "f32" }
      let widen (a : Arr) : IO Arr := convertOp a { out with el := "f32" } { out with el := "f64" }
      match binaryCode n with
      | some c =>
        if n == "stablehlo.add" || n == "stablehlo.subtract" || n == "stablehlo.multiply" then
          return #[← widen (← binary c (← narrow args[0]!) (← narrow args[1]!))]
      | none =>
        if n == "stablehlo.divide" then
          return #[← widen (← binary opDiv (← narrow args[0]!) (← narrow args[1]!))]
    if el0 == "f64" then
      match n with
      | "stablehlo.add" => return #[← f64Ew Run.f64Add args[0]! args[1]! out]
      | "stablehlo.subtract" => return #[← f64Ew Run.f64Sub args[0]! args[1]! out]
      | "stablehlo.multiply" => return #[← f64Ew Run.f64Mul args[0]! args[1]! out]
      | "stablehlo.divide" => return #[← f64Ew Run.f64Div args[0]! args[1]! out]
      | "stablehlo.floor" => return #[← f64Ew Run.f64Floor args[0]! args[0]! out]
      | "stablehlo.maximum" => return #[← f64MaxMin true args[0]! args[1]!]
      | "stablehlo.minimum" => return #[← f64MaxMin false args[0]! args[1]!]
      | "stablehlo.abs" => return #[← binary opAnd args[0]! (← u64Scalar ABS64)]
      | "stablehlo.negate" => return #[← binary opXor args[0]! (← u64Scalar SIGN64)]
      | "stablehlo.compare" => return #[← f64Compare (direction o) args[0]! args[1]!]
      | "stablehlo.sqrt" | "stablehlo.exponential" | "stablehlo.tanh" | "stablehlo.logistic"
      | "stablehlo.remainder" => err s!"{n} on f64 is not carried"
      | _ => pure ()
    -- Booleans: logical, not bitwise.
    if el0 == "i1" then
      match n with
      | "stablehlo.and" => return #[← binary opLAnd args[0]! args[1]!]
      | "stablehlo.or" => return #[← binary opLOr args[0]! args[1]!]
      | "stablehlo.xor" => return #[← binary opNe args[0]! args[1]!]
      | "stablehlo.not" => return #[← unary opNot args[0]!]
      | _ => pure ()
    if n == "stablehlo.shift_right_logical" && !el0.startsWith "ui" then
      err s!"shift_right_logical on {el0} (a signed type) is not carried"
    if let some c := unaryCode n then return #[← unary c args[0]!]
    if let some c := binaryCode n then
      if f.binaryHalf && out.el == "f32" then
        let h (a : Arr) := astype a dtF16
        return #[← astype (← binary c (← h args[0]!) (← h args[1]!)) dtF32]
      return #[← binary c args[0]! args[1]!]
    match n with
    | "stablehlo.constant" => return #[← constant o]
    | "stablehlo.divide" =>
      if out.el == "f32" && !f.divideBuiltin then
        return #[← reshape (← Run.divide args[0]! args[1]! out.count) out.dims]
      return #[← binary opDiv args[0]! args[1]!]
    | "stablehlo.sqrt" =>
      if out.el == "f32" && !f.sqrtBuiltin then
        return #[← reshape (← Run.sqrt args[0]! out.count) out.dims]
      return #[← unary opSqrt args[0]!]
    | "stablehlo.compare" => return #[← binary (← compareCode (direction o)) args[0]! args[1]!]
    | "stablehlo.select" => return #[← where_ args[0]! args[1]! args[2]!]
    | "stablehlo.reshape" => return #[← reshape args[0]! out.dims]
    | "stablehlo.transpose" =>
      let perm := ints ((o.attr? "permutation").getD "")
      if f.transposeIdentity then return #[← reshape args[0]! out.dims]
      return #[← transpose args[0]! perm]
    | "stablehlo.broadcast_in_dim" =>
      let map := ints ((o.attr? "broadcast_dimensions").getD "")
      let src := o.inTys[0]!
      if f.broadcastFirst then
        let first ← slice (← reshape args[0]! #[src.count]) #[0] #[1] #[1]
        return #[← broadcast (← reshape first (out.dims.map fun _ => 1)) out.dims]
      -- Place the operand's dims at their mapped positions, 1 elsewhere, then broadcast.
      let mut shp := Array.replicate out.dims.size 1
      for (d, k) in map.zipIdx do shp := shp.set! d (src.dims[k]!)
      return #[← broadcast (← reshape args[0]! shp) out.dims]
    | "stablehlo.slice" =>
      let st := ints ((o.attr? "start_indices").getD "")
      let li := ints ((o.attr? "limit_indices").getD "")
      let sd := ints ((o.attr? "strides").getD "")
      let sd := if sd.isEmpty then st.map fun _ => 1 else sd
      if f.sliceShift then
        let k := st.size - 1
        return #[← slice args[0]! (st.set! k (st[k]! + 1)) (li.set! k (li[k]! + 1)) sd]
      return #[← slice args[0]! st li sd]
    | "stablehlo.dynamic_slice" =>
      let src := o.inTys[0]!
      let sizes := ints ((o.attr? "slice_sizes").getD "")
      let mut st := #[]
      for (nm, d) in (o.operands.extract 1 o.operands.size).zipIdx do
        let some v := known.get? nm
          | err s!"dynamic_slice: start {d} ({nm}) depends on data, which is not carried"
        -- StableHLO clamps each start to [0, dim - size].
        let hi : Int := (src.dims[d]! : Int) - (sizes[d]! : Int)
        st := st.push (max 0 (min v hi)).toNat
      let li := (st.zip sizes).map fun (a, b) => a + b
      return #[← slice args[0]! st li (st.map fun _ => 1)]
    | "stablehlo.gather" => return #[← gather1d o args[0]! args[1]!]
    | "stablehlo.reduce" =>
      let dims := ints ((o.attr? "dimensions").getD "")
      let some body := o.regions[0]? | err "reduce without a body"
      unless body.ops.size == 1 && body.ops[0]!.name == "stablehlo.maximum" && o.operands.size == 2 do
        err "reduce: only a single-operand maximum is carried"
      if el0 == "f64" then err "reduce on f64 is not carried"
      -- Maximum is exact and order-free; the init value takes part like any element.
      let mut r := args[0]!
      for d in (dims.qsort (· > ·)) do r ← maxAxis r d.toUInt32
      return #[← binary opMax r args[1]!]
    | "stablehlo.concatenate" =>
      let d := (ints ((o.attr? "dimension").getD "0"))[0]!
      return #[← concat (if f.concatSwap then args.reverse else args) d.toUInt32]
    | "stablehlo.convert" => return #[← convertOp args[0]! o.inTys[0]! out]
    | "stablehlo.bitcast_convert" => return #[← view args[0]! (← elDtype out.el)]
    | "stablehlo.iota" =>
      let d := (ints ((o.attr? "iota_dimension").getD "0"))[0]!
      let len := out.dims[d]!
      let words := (List.range len).toArray.map (·.toUInt32)
      let base ← astype (← u32Arr words) (← elDtype out.el)
      let mut shp := Array.replicate out.dims.size 1
      shp := shp.set! d len
      return #[← broadcast (← reshape base shp) out.dims]
    | "stablehlo.dot_general" => return #[← dotGeneral f o args[0]! args[1]!]
    | "stablehlo.while" =>
      let (some cond, some body) := (o.regions[0]?, o.regions[1]?) | err "while without its two regions"
      let mut st := args
      let mut stK : Array (Option Int) := o.operands.map known.get?
      let mut prev := args
      repeat
        let (_, ck) ← runRegion m f env known cond st stK
        let c : Option Int := ck[0]?.join
        match c with
        | some v =>
          if v == 0 then break
          let (br, bk) ← runRegion m f env known body st stK
          prev := st
          st := br
          stK := bk
        | none => err "while: the condition depends on data, which is not carried (the loop is unrolled when traced)"
      return if f.whileShort then prev else st
    | "stablehlo.composite" => runComposite m f o args
    | "stablehlo.custom_call" => runComposite m f o args
    | _ => err s!"op {n} is not in the lowering table"

  partial def runComposite (m : Module) (f : Faults) (o : Op) (args : Array Arr) : IO (Array Arr) := do
    let name := ((o.attr? "name").getD ((o.attr? "call_target_name").getD "")).replace "\"" ""
    let attrs := (o.attr? "composite_attributes").getD ((o.attr? "backend_config").getD "")
    let out := o.outTys[0]!
    let (rows, cols) := rowsCols out
    match name with
    | "ggml.norm" =>
      let y ← Run.norm args[0]! cols rows (← f32Attr attrs "eps") f.normGpuOps
      return #[← reshape y out.dims]
    | "ggml.soft_max" =>
      if cols % 4 != 0 then
        err s!"ggml.soft_max: a row of {cols} has a {cols % 4}-element tail that ggml-cpu sends through the platform expf, which is not carried"
      let y ← Run.softMax args[0]! cols rows (← f32Attr attrs "scale") f.softMaxFloatSum
      return #[← reshape y out.dims]
    | "ggml.silu" =>
      if cols % 4 != 0 then
        err s!"ggml.silu: a row of {cols} has a {cols % 4}-element tail that ggml-cpu sends through the platform expf, which is not carried"
      return #[← reshape (← Run.silu args[0]! out.count f.siluGpuOps) out.dims]
    | "ggml.gelu_erf" =>
      return #[← reshape (← Run.geluErf args[0]! out.count f.geluTanh) out.dims]
    | _ =>
      let dec := ((o.attr? "decomposition").getD "").replace "@" ""
      let some fn := m.func? dec | err s!"composite {name}: no decomposition @{dec}"
      runFunc m f fn args

  /-- Run a block whose arguments are `args`, seeing the enclosing `env` (an MLIR
      region reads the values defined around it). Returns the block's results and
      which of them are scalars known at trace time. -/
  partial def runRegion (m : Module) (f : Faults) (env : Env) (known : Known) (b : Block)
      (args : Array Arr) (argK : Array (Option Int)) : IO (Array Arr × Array (Option Int)) := do
    let mut env := env
    let mut known := known
    for (((n, _), a), k) in (b.args.zip args).zip argK do
      env := env.insert n a
      known := match k with | some v => known.insert n v | none => known.erase n
    for o in b.ops do
      let rs ← runOp m f env known o
      if rs.size != o.results.size then err s!"{o.name}: {rs.size} results for {o.results.size} names"
      for (n, a) in o.results.zip rs do env := env.insert n a
      if o.results.size == 1 then
        match constEval known o with
        | some v => known := known.insert o.results[0]! v
        | none => known := known.erase o.results[0]!
    let outs ← b.ret.mapM (get env)
    return (outs, b.ret.map known.get?)

  partial def runBlock (m : Module) (f : Faults) (b : Block) (args : Array Arr) : IO (Array Arr) := do
    return (← runRegion m f {} {} b args (args.map fun _ => none)).1

  partial def runFunc (m : Module) (f : Faults) (fn : Func) (args : Array Arr) : IO (Array Arr) := do
    if args.size != fn.body.args.size then err s!"@{fn.name} takes {fn.body.args.size} arguments, got {args.size}"
    runBlock m f fn.body args
end

end StablehloMlx.Lower
