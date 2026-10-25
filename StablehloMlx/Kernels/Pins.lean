import StablehloMlx.Kernels.Shaders
import StablehloMlx.Kernels.Metal

/-!
# `StablehloMlx.Kernels.Pins` — the committed Metal comes from these Lean kernels

`StablehloMlx/Kernels/Metal.lean` is written by `lake exe emit_kernels` and
records the Slang each Metal kernel was compiled from. These checks fail the
build when a Lean kernel changes and the Metal is not re-emitted.
-/

namespace StablehloMlx.Kernels.Pins

open LeanSlang

example : emit Shaders.mulMat = Metal.mulmat.slang := by native_decide
example : emit Shaders.softMax = Metal.softmax.slang := by native_decide
example : emit Shaders.norm = Metal.norm.slang := by native_decide
example : emit Shaders.silu = Metal.silu.slang := by native_decide
example : emit Shaders.geluErf = Metal.geluerf.slang := by native_decide
example : emit Shaders.erffMap = Metal.erffmap.slang := by native_decide
example : emit Shaders.divide = Metal.divide.slang := by native_decide
example : emit Shaders.sqrt = Metal.sqrt.slang := by native_decide
example : emit Shaders.f64Ew = Metal.f64ew.slang := by native_decide
example : emit Shaders.f64OfF32 = Metal.f64off32.slang := by native_decide
example : emit Shaders.f32OfF64 = Metal.f32off64.slang := by native_decide
example : Metal.all.length = Shaders.all.length := by native_decide

end StablehloMlx.Kernels.Pins
