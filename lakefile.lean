import Lake
open Lake DSL System

/-- The macOS SDK: Lean's bundled linker does not search it by itself. -/
def sdk : String := run_io do
  let r ← IO.Process.output { cmd := "xcrun", args := #["--show-sdk-path"] }
  return r.stdout.trimAscii.toString

package StablehloMlx where
  -- mlx-c and MLX are static archives built by scripts/build_mlx.sh at pinned
  -- commits into .lake/mlx/prefix; the Metal library sits beside them.
  moreLinkArgs := #[
    ".lake/mlx/prefix/lib/libmlxc.a", ".lake/mlx/prefix/lib/libmlx.a",
    "-isysroot", sdk, "-F", sdk ++ "/System/Library/Frameworks", "-L", sdk ++ "/usr/lib",
    "-framework", "Metal", "-framework", "Foundation", "-framework", "QuartzCore",
    "-framework", "Accelerate", "-lc++"]

-- Every dependency is pinned in a V-Sekai-fire repo (the contract-anny-kernels pin).
require LeanSlang from git
  "https://github.com/V-Sekai-fire/contract-lean-slang.git" @ "60532aef8ed70cc669ecab481182d0636c9e1ac3"

/-! The one C file: the shim from Lean objects to the mlx-c ABI. -/
target shimO pkg : FilePath := do
  let oFile := pkg.buildDir / "c" / "smlx_shim.o"
  let srcJob ← inputTextFile <| pkg.dir / "c" / "smlx_shim.c"
  let flags := #["-I", (← getLeanIncludeDir).toString,
                 "-I", (pkg.dir / ".lake" / "mlx" / "prefix" / "include").toString,
                 "-fPIC", "-O2", "-Wall"]
  buildO oFile srcJob flags #[] "cc" getLeanTrace

extern_lib libsmlx pkg := do
  buildStaticLib (pkg.staticLibDir / nameToStaticLib "smlx") #[← shimO.fetch]

@[default_target] lean_lib StablehloMlx

/-- Lean kernels → Slang → Metal (slangc), written into StablehloMlx/Kernels/Metal.lean. -/
lean_exe emit_kernels where
  root := `EmitKernels

/-- The executor CLI: run a StableHLO module on the Metal GPU. -/
@[default_target] lean_exe shlo_mlx where
  root := `Main

/-- Per-op tests against ggml-cpu, with planted faults. -/
@[default_target] lean_exe op_tests where
  root := `Tests.OpTests
