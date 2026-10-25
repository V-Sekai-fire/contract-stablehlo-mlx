import StablehloMlx.Parse
import StablehloMlx.Lower

/-!
# `StablehloMlx.Exec` — load a module once, run it many times

`load` parses the text and checks that `main` exists. `prepare` traces `main`
once through `mx::compile` (or wraps it uncompiled), so a diffusion loop calls
the same compiled graph with new inputs; the weights are passed as MLX arrays
that stay on the GPU between calls.
-/

namespace StablehloMlx.Exec

open StablehloMlx.Mlx

structure Loaded where
  module : Module
  main : Func

def load (text : String) : IO Loaded := do
  match Parse.parse text with
  | .error e => throw (IO.userError e)
  | .ok m =>
    match m.func? "main" with
    | some f => return { module := m, main := f }
    | none => throw (IO.userError "the module has no @main")

/-- Trace `main` (compiled when `compile` is set). -/
def prepare (l : Loaded) (faults : Lower.Faults := {}) (compile := true) : IO Fn :=
  Mlx.compile (fun args => Lower.runFunc l.module faults l.main args) compile

/-- Run and evaluate: the outputs are on the GPU and computed when this returns. -/
def call (f : Fn) (inputs : Array Arr) : IO (Array Arr) := do
  let outs ← apply f inputs
  eval outs
  return outs

/-- The argument types of `main`, for reading raw inputs. -/
def argTys (l : Loaded) : Array Ty := l.main.body.args.map (·.2)

def arrOfBytes (t : Ty) (b : ByteArray) : IO Arr := do
  ofBytes b t.dims (← Lower.elDtype t.el)

end StablehloMlx.Exec
