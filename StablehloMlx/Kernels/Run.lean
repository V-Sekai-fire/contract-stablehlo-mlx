import StablehloMlx.Mlx
import StablehloMlx.Kernels.Metal
import StablehloMlx.Kernels.Math

/-!
# `StablehloMlx.Kernels.Run` — dispatch the generated Metal kernels through MLX

Each kernel is created once (`mx::fast::metal_kernel` compiles it on first
use and caches the pipeline) and applied to MLX arrays that stay on the GPU.
The scalar parameters travel as a small uint32 array, so one compiled kernel
serves every shape.
-/

namespace StablehloMlx.Kernels.Run

open StablehloMlx.Mlx
open StablehloMlx.Kernels

initialize cache : IO.Ref (List (String × Kernel)) ← IO.mkRef []

def kernel (s : Spec) : IO Kernel := do
  if let some k := (← cache.get).lookup s.name then return k
  let k ← kernelNew ("smlx_" ++ s.name) s.inputs s.outputs s.body s.header
  cache.modify ((s.name, k) :: ·)
  return k

def spec (name : String) : IO Spec :=
  match Metal.all.find? (·.name == name) with
  | some s => pure s
  | none => throw <| IO.userError s!"no generated kernel {name}; run lake exe emit_kernels"

/-- Apply kernel `name` to `inputs` (in its binding order), one thread per index
    below `threads`, threadgroups of `tg` (the kernel's numthreads). -/
def run (name : String) (inputs : Array Arr) (outShape : Array Nat) (outDtype : UInt8)
    (threads tg : Nat) : IO Arr := do
  let k ← kernel (← spec name)
  -- Inputs under 8 elements would be bound as `constant` (see `params`): pad
  -- them with zeros past the end, which no kernel reads.
  let inputs ← inputs.mapM fun a => do
    let n := (← shape a).foldl (· * ·) 1
    if n ≥ 8 then return a
    let pad ← astype (← u32Arr (Array.replicate (8 - n) 0)) (← dtype a).toUInt8
    concat #[← reshape a #[n], pad] 0
  let outs ← kernelApply k inputs #[outShape] (ByteArray.mk #[outDtype]) #[max threads 1, 1, 1] #[tg, 1, 1]
  return outs[0]!

/-- The scalar parameters, padded to 8 words: `metal_kernel` binds an input of
    fewer than 8 elements in the `constant` address space
    (`max_constant_array_size`, mlx/backend/common/metal_kernel.cpp), and the
    Slang-emitted body takes `device` pointers. -/
def params (ws : List Nat) : IO Arr :=
  u32Arr ((ws ++ List.replicate (8 - ws.length) (0 : Nat)).toArray.map Nat.toUInt32)

initialize erffTab : IO.Ref (Option Arr) ← IO.mkRef none

def erffTable : IO Arr := do
  if let some a := ← erffTab.get then return a
  let a ← ofBytes (wordsToBytes Math.erffTable.toArray) #[Math.erffTable.length] dtF32
  erffTab.set (some a)
  return a

/-- `ggml_mul_mat`'s dot order. `w` is `[Wb, M, K]` (Wb = 1 or the batch), `x` is
    `[R, K]` with `R = batch · N`; the result is `[R, M]`. -/
def mulMat (w x : Arr) (K M R N wBatchStride : Nat) (plain := false) : IO Arr := do
  run "mul_mat" #[w, x, ← params [K, M, R, wBatchStride, N, if plain then 1 else 0]] #[R * M] dtF32 (R * M) 64

def softMax (x : Arr) (ncols rows : Nat) (scaleBits : UInt32) (floatSum := false) : IO Arr := do
  run "soft_max" #[x, ← params [ncols, rows, scaleBits.toNat, if floatSum then 1 else 0]] #[rows * ncols] dtF32 rows 64

def norm (x : Arr) (ncols rows : Nat) (epsBits : UInt32) (gpuOps := false) : IO Arr := do
  run "norm" #[x, ← params [ncols, rows, epsBits.toNat, if gpuOps then 1 else 0]] #[rows * ncols] dtF32 rows 64

def silu (x : Arr) (count : Nat) (gpuOps := false) : IO Arr := do
  run "silu" #[x, ← params [count, if gpuOps then 1 else 0]] #[count] dtF32 count 64

def geluErf (x : Arr) (count : Nat) (gpuErf := false) : IO Arr := do
  run "gelu_erf" #[x, ← erffTable, ← params [count, if gpuErf then 1 else 0]] #[count] dtF32 count 64

def erffMap (base count : Nat) : IO Arr := do
  run "erff_map" #[← erffTable, ← params [base, count]] #[count] dtU32 count 256

def divide (a b : Arr) (count : Nat) : IO Arr := do
  run "divide" #[a, b, ← params [count]] #[count] dtF32 count 256

def sqrt (a : Arr) (count : Nat) : IO Arr := do
  run "sqrt" #[a, ← params [count]] #[count] dtF32 count 256

end StablehloMlx.Kernels.Run
