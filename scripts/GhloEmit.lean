import GgmlStablehlo.Lower

/-!
# `GhloEmit` — contract-ggml-stablehlo's emitter over the reference graphs

    (cd .lake/ggml/ghlo && lake env lean --run ../../../scripts/GhloEmit.lean <ref-dir>)

Run inside a checkout of V-Sekai-fire/contract-ggml-stablehlo (the commit
`ref/build.sh` pins), so the StableHLO is exactly what that emitter writes. For
each `<ref-dir>/<case>/graph.txt` (written by `ref/ggml_ref`) it writes
`ghlo.mlir`, the module, and `ghlo.fault.mlir` with that emitter's own planted
wrong lowering for the op, named in `ghlo.fault.txt`.
-/

open GgmlStablehlo

/-- The planted fault per op. Faults that only matter to XLA (`mulNativeF32`:
    MLX never fuses a multiply into an add) would not change MLX's bits, so
    each op gets one that changes the arithmetic or the data movement. -/
def faultFor (g : Graph) : Fault :=
  let ops := g.toList.filter (·.isNode) |>.map (·.op)
  let un := g.toList.filter (·.isNode) |>.map (·.unary)
  if ops.contains "MUL_MAT" then
    let k := (g.toList.find? (·.op == "MUL_MAT")).map (fun t => (g[(t.src 0).get!]!).ne[0]!) |>.getD 0
    -- Below 16 there is no vfmaq_f32 block to round differently.
    if decide (k ≥ (16 : Nat)) then .mulmatRoundedProduct else .mulmatUntransposed
  else if ops.contains "NORM" then .normF32Accumulate
  else if ops.contains "SOFT_MAX" then .softmaxXlaExp
  else if un.contains "GELU_ERF" then .geluTanh
  else if un.contains "SILU" then .siluLogistic
  else if ops.contains "SCALE" then .scaleSplit
  else if ops.contains "REPEAT" then .repeatInterleave
  else if ops.contains "CONCAT" then .concatAxis
  else if ops.any (fun o => o == "VIEW" || o == "TRANSPOSE" || o == "PERMUTE") then .viewDense
  else .neNotReversed

def main (args : List String) : IO UInt32 := do
  let some dir := args.head? | IO.eprintln "usage: GhloEmit <ref-dir>"; return 2
  let mut n := 0
  for e in ← System.FilePath.readDir dir do
    let gPath := e.path / "graph.txt"
    unless ← gPath.pathExists do continue
    let g ← IO.ofExcept (parseGraph (← IO.FS.readFile gPath))
    let em ← IO.ofExcept (emitGraph [] g)
    IO.FS.writeFile (e.path / "ghlo.mlir") em.text
    let f := faultFor g
    match emitGraph [f] g with
    | .ok ef => IO.FS.writeFile (e.path / "ghlo.fault.mlir") ef.text
    | .error msg => IO.FS.writeFile (e.path / "ghlo.fault.mlir") s!"// the emitter refused: {msg}\n"
    IO.FS.writeFile (e.path / "ghlo.fault.txt") (toString (repr f) ++ "\n")
    n := n + 1
  IO.println s!"{n} modules from contract-ggml-stablehlo's emitter in {dir}"
  return 0
