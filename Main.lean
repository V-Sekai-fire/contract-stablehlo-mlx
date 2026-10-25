import StablehloMlx

/-!
# `shlo_mlx` — run a StableHLO module on the Metal GPU through MLX

    shlo_mlx <module.mlir> <out-prefix> <arg0.bin> [arg1.bin …] [--no-compile] [--repeat N]

Each argument file holds `main`'s argument as raw little-endian elements in
row-major order. Each result is written to `<out-prefix><i>.bin` the same way.
`--repeat N` calls the compiled module N times and prints the per-call time.
-/

open StablehloMlx
open StablehloMlx.Mlx

def main (args : List String) : IO UInt32 := do
  let compile := !args.contains "--no-compile"
  let repeatN := match args.dropWhile (· != "--repeat") with
    | _ :: n :: _ => n.toNat!
    | _ => 1
  let pos := args.filter (fun a => !a.startsWith "--") |>.filter (fun a => a.toNat?.isNone)
  match pos with
  | modPath :: outPrefix :: inPaths =>
    let l ← Exec.load (← IO.FS.readFile modPath)
    let tys := Exec.argTys l
    if tys.size != inPaths.length then
      IO.eprintln s!"@main takes {tys.size} arguments, {inPaths.length} files given"
      return 2
    let mut ins := #[]
    for (t, p) in tys.zip inPaths.toArray do
      ins := ins.push (← Exec.arrOfBytes t (← IO.FS.readBinFile p))
    eval ins
    let t0 ← IO.monoNanosNow
    let f ← Exec.prepare l {} compile
    let mut outs ← Exec.call f ins
    let t1 ← IO.monoNanosNow
    IO.println s!"first call (trace + compile + run): {(t1 - t0).toFloat / 1e6} ms"
    if repeatN > 1 then
      let t2 ← IO.monoNanosNow
      for _ in [1:repeatN] do outs ← Exec.call f ins
      let t3 ← IO.monoNanosNow
      IO.println s!"per call over {repeatN - 1}: {(t3 - t2).toFloat / 1e6 / (repeatN - 1).toFloat} ms"
    for (o, k) in outs.zipIdx do
      IO.FS.writeBinFile s!"{outPrefix}{k}.bin" (← toBytes o)
    return 0
  | _ =>
    IO.eprintln "usage: shlo_mlx <module.mlir> <out-prefix> <arg0.bin> [arg1.bin …] [--no-compile] [--repeat N]"
    return 2
