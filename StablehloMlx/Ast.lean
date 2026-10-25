/-!
# `StablehloMlx.Ast` — the StableHLO subset this executor reads

A module is a set of `func.func`s; `main` is the entry. Ops are kept close to
the text: attribute values stay as their source text and each lowering reads
the ones it needs (`StablehloMlx.Attr`). Shapes are slowest-first, as MLIR
writes them.
-/

namespace StablehloMlx

structure Ty where
  dims : Array Nat
  el : String
  deriving Repr, BEq, Inhabited

def Ty.count (t : Ty) : Nat := t.dims.foldl (· * ·) 1
def Ty.str (t : Ty) : String :=
  "tensor<" ++ String.join (t.dims.toList.map fun d => toString d ++ "x") ++ t.el ++ ">"

mutual
  inductive Op where
    | mk (results : Array String) (name : String) (operands : Array String)
         (attrs : List (String × String)) (regions : Array Block)
         (inTys : Array Ty) (outTys : Array Ty)
  inductive Block where
    | mk (args : Array (String × Ty)) (ops : Array Op) (ret : Array String)
end

instance : Inhabited Op := ⟨.mk #[] "" #[] [] #[] #[] #[]⟩
instance : Inhabited Block := ⟨.mk #[] #[] #[]⟩

namespace Op
def results : Op → Array String | .mk r .. => r
def name : Op → String | .mk _ n .. => n
def operands : Op → Array String | .mk _ _ o .. => o
def attrs : Op → List (String × String) | .mk _ _ _ a .. => a
def regions : Op → Array Block | .mk _ _ _ _ r .. => r
def inTys : Op → Array Ty | .mk _ _ _ _ _ i _ => i
def outTys : Op → Array Ty | .mk _ _ _ _ _ _ o => o
def attr? (o : Op) (k : String) : Option String := o.attrs.lookup k
end Op

namespace Block
def args : Block → Array (String × Ty) | .mk a .. => a
def ops : Block → Array Op | .mk _ o _ => o
def ret : Block → Array String | .mk _ _ r => r
end Block

structure Func where
  name : String
  body : Block
  outTys : Array Ty
  deriving Inhabited

structure Module where
  funcs : Array Func
  deriving Inhabited

def Module.func? (m : Module) (n : String) : Option Func := m.funcs.find? (·.name == n)

end StablehloMlx
