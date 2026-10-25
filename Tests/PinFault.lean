import StablehloMlx.Kernels.Pins

/-!
# Planted fault for the kernel pins

`StablehloMlx.Kernels.Pins` proves, by `native_decide`, that each committed
Metal kernel was emitted from its Lean kernel. This file states one pin wrong
(the matmul kernel against the softmax Slang). `scripts/pin_fault.sh` checks
that Lean rejects it: if this file elaborates, the pin check proves nothing.
-/

open LeanSlang StablehloMlx.Kernels

example : emit Shaders.mulMat = Metal.softmax.slang := by native_decide
