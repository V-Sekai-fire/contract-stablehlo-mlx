import LeanSlang

/-!
# `StablehloMlx.Kernels.Dsl` — a C-like surface over the LeanSlang AST

The exact kernels are written with these helpers so that each line reads like
the ggml-cpu source it restates. Everything here builds `LeanSlang` syntax; it
computes nothing.
-/

namespace StablehloMlx.Kernels.Dsl

open LeanSlang

abbrev E := SlangExpr
abbrev S := SlangStmt

def fT : SlangType := .scalar .float
def uT : SlangType := .scalar .uint
def iT : SlangType := .scalar .int
def bT : SlangType := .scalar .bool
/-- 64-bit unsigned: the carrier of every binary64 value (the GPU has no double). -/
def lT : SlangType := .named "uint64_t"

def v (n : String) : E := .var n
def u (n : Nat) : E := .litUint n
/-- A 64-bit unsigned literal. -/
def ul (n : Nat) : E := .var (toString n ++ "ULL")
/-- The binary32 whose bit pattern is `bits`, written as a bitcast so no decimal
    round trip can move it. -/
def fbits (bits : Nat) : E := .call "asfloat" [.litUint bits]
def tru : E := .litBool true

instance : Add E := ⟨fun a b => .bin "+" a b⟩
instance : Sub E := ⟨fun a b => .bin "-" a b⟩
instance : Mul E := ⟨fun a b => .bin "*" a b⟩
instance : Div E := ⟨fun a b => .bin "/" a b⟩
instance : Mod E := ⟨fun a b => .bin "%" a b⟩
instance : HShiftLeft E E E := ⟨fun a b => .bin "<<" a b⟩
instance : HShiftRight E E E := ⟨fun a b => .bin ">>" a b⟩
instance : AndOp E := ⟨fun a b => .bin "&" a b⟩
instance : OrOp E := ⟨fun a b => .bin "|" a b⟩
instance : XorOp E := ⟨fun a b => .bin "^" a b⟩

def lt (a b : E) : E := .bin "<" a b
def le (a b : E) : E := .bin "<=" a b
def gt (a b : E) : E := .bin ">" a b
def ge (a b : E) : E := .bin ">=" a b
def eq (a b : E) : E := .bin "==" a b
def ne (a b : E) : E := .bin "!=" a b
def and_ (a b : E) : E := .bin "&&" a b
def or_ (a b : E) : E := .bin "||" a b
def not_ (a : E) : E := .un "!" a
def sel (c t f : E) : E := .ternary c t f
def neg (a : E) : E := .un "-" a

/-- A fused multiply-add, one rounding: `a * b + c`. -/
def fma (a b c : E) : E := .call "fma" [a, b, c]
def asuint (a : E) : E := .call "asuint" [a]
def asfloat (a : E) : E := .call "asfloat" [a]
def toU (a : E) : E := .cast uT a
def toL (a : E) : E := .cast lT a
def toF (a : E) : E := .cast fT a
def toI (a : E) : E := .cast iT a
def call (f : String) (args : List E) : E := .call f args
def at_ (buf : String) (i : E) : E := .index (v buf) i

def let_ (ty : SlangType) (n : String) (e : E) : S := .declare ty n (some e)
def var_ (ty : SlangType) (n : String) : S := .declare ty n none
def set (n : String) (e : E) : S := .assign (v n) e
def setAt (buf : String) (i e : E) : S := .assign (.index (v buf) i) e
def if_ (c : E) (t : List S) (f : List S := []) : S := .ifThen c t f
def ret (e : E) : S := .ret (some e)
def retv : S := .ret none
def for_ (n : String) (lo hi : E) (body : List S) : S := .forCount n lo hi body
def while_ (c : E) (body : List S) : S := .whileLoop c body

def param (n : String) (ty : SlangType) : SlangBinding := { name := n, type := ty }

/-- A helper function (not an entry point). -/
def fn (ret : SlangType) (n : String) (ps : List (String × SlangType)) (body : List S) : SlangFunctionDecl :=
  { retType := ret, name := n, params := ps.map fun (a, t) => param a t, body := body }

/-- Read-only and read-write float/uint buffers, bound in declaration order. -/
def roF (n : String) (b : Nat) : SlangBinding := { name := n, type := .roBuf fT, binding := some b }
def roU (n : String) (b : Nat) : SlangBinding := { name := n, type := .roBuf uT, binding := some b }
def rwF (n : String) (b : Nat) : SlangBinding := { name := n, type := .rwBuf fT, binding := some b }
def rwU (n : String) (b : Nat) : SlangBinding := { name := n, type := .rwBuf uT, binding := some b }

/-- The compute entry point: one thread per `tid.x`, the global index. -/
def entry (threads : Nat) (body : List S) : SlangFunctionDecl :=
  { attrs := [.shaderCompute, .numthreads threads 1 1]
    name := "main"
    params := [{ name := "tid", type := .vec .uint 3, semantic := .svDispatchThreadId }]
    body := body }

end StablehloMlx.Kernels.Dsl
