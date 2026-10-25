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
    | _ => s
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

def compareCode (dir : String) : IO UInt32 :=
  if dir.endsWith "EQ" then pure opEq else if dir.endsWith "NE" then pure opNe
  else if dir.endsWith "LT" then pure opLt else if dir.endsWith "LE" then pure opLe
  else if dir.endsWith "GT" then pure opGt else if dir.endsWith "GE" then pure opGe
  else err s!"comparison {dir}"

/-- The rows-and-columns view ggml's row ops take: the last dimension is a row. -/
def rowsCols (t : Ty) : Nat × Nat :=
  let c := t.dims.back?.getD 1
  (t.count / max c 1, c)

mutual
  partial def runOp (m : Module) (f : Faults) (env : Env) (o : Op) : IO (Array Arr) := do
    let args ← o.operands.mapM (get env)
    let out := o.outTys[0]?.getD default
    let n := o.name
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
    | "stablehlo.compare" =>
      let dir := (o.attr? "comparison_direction").getD ""
      return #[← binary (← compareCode dir) args[0]! args[1]!]
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
    | "stablehlo.concatenate" =>
      let d := (ints ((o.attr? "dimension").getD "0"))[0]!
      return #[← concat (if f.concatSwap then args.reverse else args) d.toUInt32]
    | "stablehlo.convert" =>
      if o.inTys[0]!.el == "f64" || out.el == "f64" then err "convert to or from f64 is not carried yet"
      return #[← astype args[0]! (← elDtype out.el)]
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

  partial def runBlock (m : Module) (f : Faults) (b : Block) (args : Array Arr) : IO (Array Arr) := do
    let mut env : Env := {}
    for ((n, _), a) in b.args.zip args do env := env.insert n a
    for o in b.ops do
      let rs ← runOp m f env o
      if rs.size != o.results.size then err s!"{o.name}: {rs.size} results for {o.results.size} names"
      for (n, a) in o.results.zip rs do env := env.insert n a
    b.ret.mapM (get env)

  partial def runFunc (m : Module) (f : Faults) (fn : Func) (args : Array Arr) : IO (Array Arr) := do
    if args.size != fn.body.args.size then err s!"@{fn.name} takes {fn.body.args.size} arguments, got {args.size}"
    runBlock m f fn.body args
end

end StablehloMlx.Lower
