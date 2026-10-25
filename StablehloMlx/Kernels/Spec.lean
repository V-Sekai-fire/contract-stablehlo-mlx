/-!
# `StablehloMlx.Kernels.Spec` — one generated Metal kernel, as `metal_kernel` takes it
-/

namespace StablehloMlx.Kernels

structure Spec where
  name : String
  /-- The Slang this Metal was compiled from (pinned against the Lean kernel). -/
  slang : String
  inputs : Array String
  outputs : Array String
  header : String
  body : String

end StablehloMlx.Kernels
