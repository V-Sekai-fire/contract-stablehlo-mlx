import StablehloMlx

/-!
# `op_tests` — every op against ggml-cpu, bit for bit, on the Metal GPU

    op_tests <ref-dir> [--pinned <pinned-ref-dir>] [case …]

`<ref-dir>` is written by `ref/ggml_ref` (ggml-cpu, one op per case). For each
case this builds the StableHLO module for that ggml op, runs it on the GPU
through MLX twice (traced under `mx::compile`, and uncompiled), and compares
every output bit with ggml-cpu's. Then it runs the case again with that op's
planted wrong lowering, which must give different bits (or refuse to run).

Two checks have no ggml graph: `erff_exhaustive` compares the GPU port of the
platform `erff` with the CPU routine on all 2^32 binary32 inputs, and
`builtin_divide` / `builtin_sqrt` / `builtin_matmul` measure whether MLX's own
kernels are exact (they decide which ops need a custom kernel).

With `--pinned`, every case also runs as the StableHLO that
contract-ggml-stablehlo emits for it (`<case>/ghlo.mlir`, written by
`scripts/GhloEmit.lean`), on the generic path, against that repository's
reference build (`ref/build.sh <dir> pinned`). Two planted faults each: the
emitter's own wrong lowering (`ghlo.fault.mlir`) and a wrong lowering in this
executor (binary64 done in binary32, or a while loop one iteration short).

A case whose reference directory or module is missing is a FAIL, not a skip.
-/

open StablehloMlx
open StablehloMlx.Mlx

/-- ggml `ne` (fastest first) as a rank-3 MLIR type (slowest first). -/
def tyOf (ne : Array Nat) : Ty := { dims := #[ne[2]!, ne[1]!, ne[0]!], el := "f32" }

def hex32 (b : UInt32) : String :=
  let ds := Nat.toDigits 16 b.toNat
  "0x" ++ (String.ofList (List.replicate (8 - ds.length) '0' ++ ds)).toUpper

def fnHeader (args : List Ty) (outs : List Ty) : String :=
  "module {\n  func.func public @main(" ++
  ", ".intercalate ((args.zipIdx).map fun (t, i) => s!"%a{i}: {t.str}") ++ ") -> (" ++
  ", ".intercalate (outs.map Ty.str) ++ ") {\n"

def fnFooter (r : String) (t : Ty) : String := s!"    func.return {r} : {t.str}\n  }\n}\n"

def unaryCall (target attrs : String) (t : Ty) : String :=
  fnHeader [t] [t] ++
  s!"    %0 = \"stablehlo.custom_call\"(%a0) \{call_target_name = \"{target}\", backend_config = \"{attrs}\"} : ({t.str}) -> {t.str}\n" ++
  fnFooter "%0" t

/-- The StableHLO for one ggml op, from the case's tensor shapes. -/
def moduleFor (op : String) (ins : Array (Array Nat)) (out : Array Nat) : IO String := do
  let to := tyOf out
  match op with
  | "mul_mat" =>
    let w := ins[0]!
    let x := ins[1]!
    let tw := tyOf w
    let tx := tyOf x
    let tr : Ty := { dims := #[x[2]!, x[1]!, w[2]!, w[1]!], el := "f32" }
    return fnHeader [tw, tx] [to] ++
      s!"    %0 = \"stablehlo.dot_general\"(%a1, %a0) \{dot_dimension_numbers = #stablehlo.dot<lhs_contracting_dimensions = [2], rhs_contracting_dimensions = [2]>} : ({tx.str}, {tw.str}) -> {tr.str}\n" ++
      s!"    %1 = \"stablehlo.reshape\"(%0) : ({tr.str}) -> {to.str}\n" ++ fnFooter "%1" to
  | "add" | "mul" =>
    let n := if op == "add" then "stablehlo.add" else "stablehlo.multiply"
    return fnHeader [to, to] [to] ++
      s!"    %0 = \"{n}\"(%a0, %a1) : ({to.str}, {to.str}) -> {to.str}\n" ++ fnFooter "%0" to
  | "repeat" =>
    let ti := tyOf ins[0]!
    return fnHeader [ti] [to] ++
      s!"    %0 = \"stablehlo.broadcast_in_dim\"(%a0) \{broadcast_dimensions = array<i64: 0, 1, 2>} : ({ti.str}) -> {to.str}\n" ++
      fnFooter "%0" to
  | "scale" =>
    -- Kimodo's attention scale, 1/sqrt(head_width), computed in binary32 as ggml_ref does.
    let s : Float32 := 1.0 / Float32.sqrt 128.0
    let st : Ty := { dims := #[], el := "f32" }
    return fnHeader [to] [to] ++
      s!"    %0 = \"stablehlo.constant\"() \{value = dense<{hex32 s.toBits}> : tensor<f32>} : () -> tensor<f32>\n" ++
      s!"    %1 = \"stablehlo.broadcast_in_dim\"(%0) \{broadcast_dimensions = array<i64>} : ({st.str}) -> {to.str}\n" ++
      s!"    %2 = \"stablehlo.multiply\"(%a0, %1) : ({to.str}, {to.str}) -> {to.str}\n" ++ fnFooter "%2" to
  | "norm" => return unaryCall "ggml.norm" "eps = 0x3727C5AC : f32" to   -- 1e-5f, Kimodo's eps
  | "soft_max" => return unaryCall "ggml.soft_max" "scale = 0x3F800000 : f32" to
  | "gelu_erf" => return unaryCall "ggml.gelu_erf" "" to
  | "silu" => return unaryCall "ggml.silu" "" to
  | "concat0" | "concat1" | "concat2" =>
    let d := 2 - (op.drop 6).toString.toNat!
    let ta := tyOf ins[0]!
    let tb := tyOf ins[1]!
    return fnHeader [ta, tb] [to] ++
      s!"    %0 = \"stablehlo.concatenate\"(%a0, %a1) \{dimension = {d} : i64} : ({ta.str}, {tb.str}) -> {to.str}\n" ++
      fnFooter "%0" to
  | "transpose" =>
    let ti := tyOf ins[0]!
    return fnHeader [ti] [to] ++
      s!"    %0 = \"stablehlo.transpose\"(%a0) \{permutation = array<i64: 0, 2, 1>} : ({ti.str}) -> {to.str}\n" ++
      fnFooter "%0" to
  | _ => throw (IO.userError s!"no module builder for {op}")

/-- The view cases need the offset, which the shapes do not carry: the case
    table gives it (ggml_ref.c, view_c). -/
def viewModule (inp out : Array Nat) (off : Nat) : String :=
  let ti := tyOf inp
  let to := tyOf out
  fnHeader [ti] [to] ++
    s!"    %0 = \"stablehlo.slice\"(%a0) \{start_indices = array<i64: 0, 0, {off}>, limit_indices = array<i64: 1, {out[1]!}, {off + out[0]!}>, strides = array<i64: 1, 1, 1>} : ({ti.str}) -> {to.str}\n" ++
    fnFooter "%0" to

structure Case where
  name : String
  op : String
  fault : Lower.Faults
  faultName : String
  viewOffset : Nat := 0
  /-- A case ggml-cpu computes with code this executor does not carry: the
      lowering must refuse it, naming why, rather than return other bits. -/
  expectRefusal : Bool := false

/-- Every ggml_ref case (the same list as ref/ggml_ref.c), with its planted fault. -/
def cases : List Case :=
  let mm (n : String) : Case := { name := n, op := "mul_mat", fault := { dotBuiltin := true }, faultName := "MLX built-in matmul" }
  let mmPlain (n : String) : Case := { name := n, op := "mul_mat", fault := { dotPlain := true }, faultName := "sequential sum without FMA" }
  [ mmPlain "mul_mat_small", mmPlain "mul_mat_k2", mm "mul_mat_qkv", mm "mul_mat_ffn2", mm "mul_mat_text",
    mmPlain "mul_mat_heading", mm "mul_mat_root_in", mm "mul_mat_body_in", mm "mul_mat_scores", mm "mul_mat_value" ] ++
  [ "add_small", "add_kimodo" ].map (fun n => { name := n, op := "add", fault := { binaryHalf := true }, faultName := "float16 arithmetic" }) ++
  [ "mul_small", "mul_kimodo" ].map (fun n => { name := n, op := "mul", fault := { binaryHalf := true }, faultName := "float16 arithmetic" }) ++
  [ "scale_small", "scale_kimodo" ].map (fun n => { name := n, op := "scale", fault := { binaryHalf := true }, faultName := "float16 arithmetic" }) ++
  [ "repeat_small", "repeat_kimodo" ].map (fun n => { name := n, op := "repeat", fault := { broadcastFirst := true }, faultName := "broadcast of the first element" }) ++
  [ "norm_small", "norm_kimodo" ].map (fun n => { name := n, op := "norm", fault := { normGpuOps := true }, faultName := "binary32 sums and GPU / and sqrt" }) ++
  [ "soft_max_small", "soft_max_kimodo" ].map (fun n => { name := n, op := "soft_max", fault := { softMaxFloatSum := true }, faultName := "binary32 denominator" }) ++
  [ { name := "soft_max_tail", op := "soft_max", fault := {}, faultName := "", expectRefusal := true } ] ++
  [ "gelu_erf_small", "gelu_erf_kimodo" ].map (fun n => { name := n, op := "gelu_erf", fault := { geluTanh := true }, faultName := "tanh-form GELU" }) ++
  [ "silu_small", "silu_kimodo" ].map (fun n => { name := n, op := "silu", fault := { siluGpuOps := true }, faultName := "GPU exp and /" }) ++
  [ { name := "silu_tail", op := "silu", fault := {}, faultName := "", expectRefusal := true } ] ++
  [ ("concat0_small", "concat0"), ("concat1_small", "concat1"), ("concat2_small", "concat2"),
    ("concat0_kimodo", "concat0"), ("concat1_kimodo", "concat1"), ("concat2_kimodo", "concat2") ].map
    (fun (n, o) => { name := n, op := o, fault := { concatSwap := true }, faultName := "operands swapped" }) ++
  [ "transpose_small", "transpose_kimodo" ].map (fun n => { name := n, op := "transpose", fault := { transposeIdentity := true }, faultName := "no permutation" }) ++
  [ { name := "view_small", op := "view", fault := { sliceShift := true }, faultName := "offset one late", viewOffset := 8 },
    { name := "view_kimodo", op := "view", fault := { sliceShift := true }, faultName := "offset one late", viewOffset := 1024 + 3 * 128 } ]

def readMeta (dir : String) : IO (Array (String × Array Nat)) := do
  let lines := (← IO.FS.readFile (dir ++ "/meta.txt")).splitOn "\n" |>.filter (!·.isEmpty)
  return lines.toArray.map fun l =>
    let ws := l.splitOn " "
    (ws.head!, (ws.drop 1).toArray.map String.toNat!)

/-- Compare two byte arrays as binary32 words: (mismatches, first index). -/
def diff (a b : ByteArray) : Nat × Option Nat := Id.run do
  if a.size != b.size then return (max a.size b.size, some 0)
  let mut n := 0
  let mut first := none
  let mut i := 0
  while i + 3 < a.size do
    if a[i]! != b[i]! || a[i+1]! != b[i+1]! || a[i+2]! != b[i+2]! || a[i+3]! != b[i+3]! then
      n := n + 1
      if first.isNone then first := some (i / 4)
    i := i + 4
  return (n, first)

def word (b : ByteArray) (k : Nat) : UInt32 :=
  b[4*k]!.toUInt32 ||| (b[4*k+1]!.toUInt32 <<< 8) ||| (b[4*k+2]!.toUInt32 <<< 16) ||| (b[4*k+3]!.toUInt32 <<< 24)

structure Tally where
  pass : Nat := 0
  fail : Nat := 0
  lines : Array String := #[]

def note (t : Tally) (ok : Bool) (line : String) : IO Tally := do
  IO.println ((if ok then "PASS " else "FAIL ") ++ line)
  return { t with pass := t.pass + (if ok then 1 else 0), fail := t.fail + (if ok then 0 else 1), lines := t.lines.push line }

def runModule (text : String) (ins : Array Arr) (faults : Lower.Faults) (compile : Bool) : IO (Except String ByteArray) := do
  try
    let l ← Exec.load text
    let f ← Exec.prepare l faults compile
    let outs ← Exec.call f ins
    return .ok (← toBytes outs[0]!)
  catch e => return .error (toString e)

def runCase (ref : String) (t : Tally) (c : Case) : IO Tally := do
  let dir := ref ++ "/" ++ c.name
  unless ← System.FilePath.pathExists (dir ++ "/meta.txt") do
    return ← note t false s!"{c.name}: reference missing ({dir})"
  let md ← readMeta dir
  let inMeta := md.filter (·.1.startsWith "in")
  let some (_, outNe) := md.find? (·.1 == "out") | return ← note t false s!"{c.name}: no out in meta"
  let text ← if c.op == "view" then pure (viewModule inMeta[0]!.2 outNe c.viewOffset)
    else moduleFor c.op (inMeta.map (·.2)) outNe
  let mut ins := #[]
  for (n, ne) in inMeta do
    ins := ins.push (← ofBytes (← IO.FS.readBinFile s!"{dir}/{n}.f32") (tyOf ne).dims dtF32)
  eval ins
  let want ← IO.FS.readBinFile (dir ++ "/out.f32")
  let count := want.size / 4
  let mut t := t
  if c.expectRefusal then
    match ← runModule text ins {} true with
    | .error e =>
      let ok := (e.splitOn "not carried").length > 1
      return ← note t ok s!"{c.name}: GAP, refused as expected: {e}"
    | .ok _ => return ← note t false s!"{c.name}: ran, but it reaches code this executor does not carry"
  for compile in [true, false] do
    let mode := if compile then "compiled" else "uncompiled"
    let t0 ← IO.monoNanosNow
    let r ← runModule text ins {} compile
    let t1 ← IO.monoNanosNow
    let ms := (t1 - t0).toFloat / 1e6
    match r with
    | .error e => t ← note t false s!"{c.name} [{mode}]: did not run: {e}"
    | .ok got =>
      let (n, first) := diff got want
      let detail := match first with
        | some k => s!" first at {k}: got {hex32 (word got k)} want {hex32 (word want k)}"
        | none => ""
      t ← note t (n == 0) s!"{c.name} [{mode}]: {n} of {count} words differ{detail} ({ms} ms incl. trace)"
  -- The planted wrong lowering must be caught.
  match ← runModule text ins c.fault true with
  | .error e => t ← note t true s!"{c.name} planted fault ({c.faultName}): refused to run: {e.take 120}"
  | .ok got =>
    let (n, _) := diff got want
    t ← note t (n != 0) s!"{c.name} planted fault ({c.faultName}): {n} of {count} words differ (must be > 0)"
  return t

/-! ## Checks with no ggml graph -/

def lcg (s : UInt32) : UInt32 := s * 1664525 + 1013904223

/-- Random binary32 bit patterns of finite, normal values (exponent field 1–254). -/
def randomNormals (n : Nat) (seed : UInt32) (maxExp : UInt32 := 254) : Array UInt32 := Id.run do
  let mut s := seed
  let mut out : Array UInt32 := Array.emptyWithCapacity n
  for _ in [0:n] do
    s := lcg s
    let a := s
    s := lcg s
    let e : UInt32 := (1 : UInt32) + (s >>> (8 : UInt32)) % maxExp
    out := out.push ((a &&& (0x807FFFFF : UInt32)) ||| (e <<< (23 : UInt32)))
  return out

def builtinProbes (t : Tally) : IO Tally := do
  let mut t := t
  let n := 1 <<< 20
  let a := randomNormals n 7 200
  let b := randomNormals n 11 200
  let fa ← ofBytes (wordsToBytes a) #[n] dtF32
  let fb ← ofBytes (wordsToBytes b) #[n] dtF32
  -- CPU reference: Lean's Float32 is the host's IEEE binary32 (correctly rounded / and sqrt).
  let wantDiv := (a.zip b).map fun (x, y) => (Float32.ofBits x / Float32.ofBits y).toBits
  let wantSqrt := a.map fun x => (Float32.sqrt (Float32.ofBits (x &&& 0x7FFFFFFF))).toBits
  let absA ← ofBytes (wordsToBytes (a.map (· &&& 0x7FFFFFFF))) #[n] dtF32
  let builtinDiv ← toBytes (← binary opDiv fa fb)
  let exactDiv ← toBytes (← Kernels.Run.divide fa fb n)
  let builtinSqrt ← toBytes (← unary opSqrt absA)
  let exactSqrt ← toBytes (← Kernels.Run.sqrt absA n)
  let (d1, _) := diff builtinDiv (wordsToBytes wantDiv)
  let (d2, _) := diff exactDiv (wordsToBytes wantDiv)
  let (d3, _) := diff builtinSqrt (wordsToBytes wantSqrt)
  let (d4, _) := diff exactSqrt (wordsToBytes wantSqrt)
  IO.println s!"INFO builtin_divide: MLX's / differs from IEEE on {d1} of {n} random normal pairs"
  IO.println s!"INFO builtin_sqrt: MLX's sqrt differs from IEEE on {d3} of {n} random normals"
  t ← note t (d2 == 0) s!"exact_divide kernel: {d2} of {n} differ from IEEE"
  t ← note t (d4 == 0) s!"exact_sqrt kernel: {d4} of {n} differ from IEEE"
  -- Planted: MLX's own `/` in place of the exact kernel.
  t ← note t (d1 != 0) s!"exact_divide planted fault (MLX built-in /): {d1} of {n} differ (must be > 0)"
  -- Planted: MLX's sqrt matches IEEE on these inputs, so the planted fault is the
  -- exact kernel fed each input with its last fraction bit flipped.
  let nudged ← ofBytes (wordsToBytes (a.map fun x => (x &&& 0x7FFFFFFF) ^^^ 1)) #[n] dtF32
  let (d5, _) := diff (← toBytes (← Kernels.Run.sqrt nudged n)) (wordsToBytes wantSqrt)
  t ← note t (d5 != 0) s!"exact_sqrt planted fault (input one ulp off): {d5} of {n} differ (must be > 0)"
  return t

/-- The GPU port of the platform erff against the CPU routine, every input. -/
def erffExhaustive (t : Tally) (chunkLog : Nat := 24) : IO Tally := do
  let chunk := 1 <<< chunkLog
  let chunks := (1 <<< 32) / chunk
  let mut bad := 0
  let mut firstBad : Option Nat := none
  let t0 ← IO.monoNanosNow
  for c in [0:chunks] do
    let base := c * chunk
    let gpu ← Kernels.Run.erffMap base chunk
    let cpu ← ofBytes (← libmErffRange base.toUInt32 chunk.toUInt32) #[chunk] dtU32
    let ne ← binary opNe gpu cpu
    let k ← countNonzero ne
    if k > 0 then
      -- NaN payloads count: the CPU returns x + x, so the bits must match too.
      bad := bad + k
      if firstBad.isNone then firstBad := some base
  let t1 ← IO.monoNanosNow
  let mut t ← note t (bad == 0) s!"erff_exhaustive: {bad} of 4294967296 inputs differ from the platform erff{match firstBad with | some b => s!" (first in chunk at {hex32 b.toUInt32})" | none => ""} ({(t1 - t0).toFloat / 1e9} s)"
  -- Planted: compare against the CPU routine one input late.
  let gpu ← Kernels.Run.erffMap 0x3F000000 chunk
  let cpu ← ofBytes (← libmErffRange 0x3F000001 chunk.toUInt32) #[chunk] dtU32
  let k ← countNonzero (← binary opNe gpu cpu)
  t ← note t (k != 0) s!"erff_exhaustive planted fault (reference shifted by one input): {k} of {chunk} differ (must be > 0)"
  return t

/-! ## The generic path: contract-ggml-stablehlo's modules -/

def runGhlo (text : String) (ins : Array Arr) (faults : Lower.Faults) : IO (Except String ByteArray) := do
  runModule text ((#[← u64Scalar 0] : Array Arr) ++ ins) faults true

def ghloCase (pinned : String) (t : Tally) (name : String) : IO Tally := do
  let dir := pinned ++ "/" ++ name
  unless ← System.FilePath.pathExists (dir ++ "/ghlo.mlir") do
    return ← note t false s!"ghlo {name}: module missing ({dir}/ghlo.mlir; run scripts/GhloEmit.lean)"
  let md ← readMeta dir
  let text ← IO.FS.readFile (dir ++ "/ghlo.mlir")
  -- The module's own argument types (rank 4, after the leading ui64 zero).
  let tys := (Exec.argTys (← Exec.load text)).extract 1
  let inNames := (md.filter (·.1.startsWith "in")).map (·.1)
  if tys.size != inNames.size then
    return ← note t false s!"ghlo {name}: module takes {tys.size} tensors, the case has {inNames.size}"
  let mut ins := #[]
  for (n, ty) in inNames.zip tys do
    ins := ins.push (← Exec.arrOfBytes ty (← IO.FS.readBinFile s!"{dir}/{n}.f32"))
  eval ins
  let want ← IO.FS.readBinFile (dir ++ "/out.f32")
  let count := want.size / 4
  let mut t := t
  let t0 ← IO.monoNanosNow
  let r ← runGhlo text ins {}
  let ms := ((← IO.monoNanosNow) - t0).toFloat / 1e6
  match r with
  | .error e => t ← note t false s!"ghlo {name}: did not run: {e.take 300}"
  | .ok got =>
    let (n, first) := diff got want
    let detail := match first with
      | some k => s!" first at {k}: got {hex32 (word got k)} want {hex32 (word want k)}"
      | none => ""
    t ← note t (n == 0) s!"ghlo {name}: {n} of {count} words differ{detail} ({ms} ms incl. trace)"
  -- The emitter's planted fault (none for a lone ADD or MUL: see GhloEmit.lean).
  if ← System.FilePath.pathExists (dir ++ "/ghlo.fault.txt") then
    let fName := ((← IO.FS.readFile (dir ++ "/ghlo.fault.txt")).trimAscii).toString
    match ← runGhlo (← IO.FS.readFile (dir ++ "/ghlo.fault.mlir")) ins {} with
    | .error e => t ← note t true s!"ghlo {name} emitter fault ({fName}): refused: {e.take 100}"
    | .ok got =>
      let (n, _) := diff got want
      t ← note t (n != 0) s!"ghlo {name} emitter fault ({fName}): {n} of {count} differ (must be > 0)"
  -- This executor's planted fault: the first that the module has something to break for.
  let has (k : String) := (text.splitOn k).length > 1
  let pick : Option (Lower.Faults × String) :=
    if has "f64>" then some ({ f64AsF32 := true }, "binary64 done in binary32")
    else if has "stablehlo.while" then some ({ whileShort := true }, "while one iteration short")
    else if has "stablehlo.add\"" || has "stablehlo.multiply\"" then some ({ binaryHalf := true }, "float16 arithmetic")
    else if has "stablehlo.concatenate" then some ({ concatSwap := true }, "operands swapped")
    else if has "stablehlo.transpose" then some ({ transposeIdentity := true }, "no permutation")
    else if has "stablehlo.slice" then some ({ sliceShift := true }, "offset one late")
    else if has "stablehlo.broadcast_in_dim" then some ({ broadcastFirst := true }, "broadcast of the first element")
    else none
  match pick with
  | none => t ← note t false s!"ghlo {name}: no executor fault applies to this module"
  | some (fs, fn) =>
    match ← runGhlo text ins fs with
    | .error e => t ← note t true s!"ghlo {name} executor fault ({fn}): refused: {e.take 100}"
    | .ok got =>
      let (n, _) := diff got want
      t ← note t (n != 0) s!"ghlo {name} executor fault ({fn}): {n} of {count} differ (must be > 0)"
  return t

def main (args : List String) : IO UInt32 := do
  let pinned := match args.dropWhile (· != "--pinned") with
    | _ :: d :: _ => some d
    | _ => none
  let args := match args.dropWhile (· != "--pinned") with
    | _ :: _ :: rest => args.takeWhile (· != "--pinned") ++ rest
    | _ => args
  match args with
  | [] => IO.eprintln "usage: op_tests <ref-dir> [--pinned <pinned-ref-dir>] [case …]"; return 2
  | ref :: only =>
    let mut t : Tally := {}
    let want (n : String) := only.isEmpty || only.contains n
    if want "builtin" then t ← builtinProbes t
    for c in cases do
      if want c.name then t ← runCase ref t c
    if let some p := pinned then
      for c in cases do
        if want c.name then t ← ghloCase p t c.name
    if want "erff_exhaustive" then t ← erffExhaustive t
    IO.println s!"\n{t.pass} passed, {t.fail} failed"
    return if t.fail == 0 then 0 else 1
