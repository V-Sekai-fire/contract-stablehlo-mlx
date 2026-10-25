import StablehloMlx.Ast

/-!
# `StablehloMlx.Parse` — a dependency-free reader for StableHLO text

Reads the generic operation form that `ggml-stablehlo`'s text builder writes
(`%r = "stablehlo.add"(%a, %b) {attrs} : (T, T) -> T`, regions for `while`,
`reduce` and `composite` bodies), inside `module { func.func ... }`, plus the
`func.return` / `return` terminators of the printed form. No LLVM, no MLIR.
-/

namespace StablehloMlx.Parse

structure St where
  s : Array Char
  i : Nat := 0

abbrev P := StateT St (Except String)

def peek? : P (Option Char) := do let st ← get; return st.s[st.i]?
def bump : P Unit := modify fun st => { st with i := st.i + 1 }

def fail (msg : String) : P α := do
  let st ← get
  let ctx := String.ofList ((st.s.extract st.i (st.i + 60)).toList)
  throw s!"parse error at {st.i}: {msg}; next: {ctx.quote}"

partial def ws : P Unit := do
  match ← peek? with
  | some c =>
    if c == ' ' || c == '\n' || c == '\t' || c == '\r' then bump; ws
    else if c == '/' then
      let st ← get
      if st.s[st.i + 1]? == some '/' then
        let rec skip : P Unit := do
          match ← peek? with
          | some '\n' => pure ()
          | some _ => bump; skip
          | none => pure ()
        skip; ws
  | none => pure ()

def startsWith (lit : String) : P Bool := do
  let st ← get
  let cs := lit.toList
  return (List.range cs.length).all fun k => st.s[st.i + k]? == cs[k]?

def tryLit (lit : String) : P Bool := do
  ws
  if ← startsWith lit then
    modify fun st => { st with i := st.i + lit.length }
    return true
  return false

def lit (l : String) : P Unit := do
  unless ← tryLit l do fail s!"expected {l.quote}"

def isIdChar (c : Char) : Bool := c.isAlphanum || c == '_' || c == '.' || c == '$' || c == '-'

partial def takeWhile (p : Char → Bool) (acc : String := "") : P String := do
  match ← peek? with
  | some c => if p c then bump; takeWhile p (acc.push c) else return acc
  | none => return acc

/-- `%name`, `%name#k`, or `%name:n` (a multi-result definition; the count is returned). -/
def ssa : P (String × Option Nat) := do
  ws
  unless (← peek?) == some '%' do fail "expected %"
  bump
  let n ← takeWhile isIdChar
  if (← peek?) == some '#' then
    bump
    let k ← takeWhile Char.isDigit
    return ("%" ++ n ++ "#" ++ k, none)
  if (← peek?) == some ':' then
    let st ← get
    if (st.s[st.i + 1]?.map Char.isDigit).getD false then
      bump
      let k ← takeWhile Char.isDigit
      return ("%" ++ n, some k.toNat!)
  return ("%" ++ n, none)

def ssaUse : P String := do return (← ssa).1

partial def ty : P Ty := do
  ws
  if ← tryLit "tensor<" then
    let mut dims := #[]
    let mut el := ""
    repeat
      let d ← takeWhile Char.isDigit
      if d.isEmpty then
        el ← takeWhile fun c => c != '>'
        break
      dims := dims.push d.toNat!
      unless (← peek?) == some 'x' do fail "expected x in tensor type"
      bump
    lit ">"
    return { dims, el }
  let el ← takeWhile isIdChar
  if el.isEmpty then fail "expected a type"
  return { dims := #[], el }

partial def sepBy (p : P α) (close : String) : P (Array α) := do
  if ← tryLit close then return #[]
  let mut xs := #[← p]
  while ← tryLit "," do xs := xs.push (← p)
  lit close
  return xs

/-- `(T, T)` or a single `T`; `()` is empty. -/
def tyList : P (Array Ty) := do
  if ← tryLit "(" then sepBy ty ")" else return #[← ty]

/-- Raw text of one attribute value: up to a top-level `,` or `}`, balancing
    brackets and skipping quoted strings. -/
partial def rawValue : P String := do
  ws
  let rec go (depth : Nat) (acc : String) : P String := do
    match ← peek? with
    | none => return acc
    | some c =>
      if depth == 0 && (c == ',' || c == '}') then return acc.trimAscii.toString
      if c == '"' then
        bump
        let s ← takeWhile (· != '"')
        bump
        go depth (acc ++ "\"" ++ s ++ "\"")
      else if c == '(' || c == '[' || c == '{' || c == '<' then bump; go (depth + 1) (acc.push c)
      else if c == ')' || c == ']' || c == '}' || c == '>' then
        -- `->` is an arrow, not a closing bracket.
        if c == '>' && acc.endsWith "-" then bump; go depth (acc.push c)
        else bump; go (depth - 1) (acc.push c)
      else bump; go depth (acc.push c)
  go 0 ""

def attrDict : P (List (String × String)) := do
  lit "{"
  let kv : P (String × String) := do
    ws
    let k ← takeWhile isIdChar
    if k.isEmpty then fail "expected an attribute name"
    if ← tryLit "=" then return (k, ← rawValue) else return (k, "unit")
  return (← sepBy kv "}").toList

mutual
  partial def block : P Block := do
    lit "{"
    let mut args := #[]
    if ← tryLit "^" then
      discard <| takeWhile isIdChar
      if ← tryLit "(" then
        args ← sepBy (do let n ← ssaUse; lit ":"; let t ← ty; return (n, t)) ")"
      lit ":"
    let mut ops := #[]
    let mut ret := #[]
    repeat
      if ← tryLit "}" then break
      let o ← op
      if o.name == "stablehlo.return" || o.name == "func.return" || o.name == "return" then
        ret := o.operands
      else ops := ops.push o
    return .mk args ops ret

  partial def op : P Op := do
    ws
    let mut results := #[]
    if (← peek?) == some '%' then
      let mut defs := #[← ssa]
      while ← tryLit "," do defs := defs.push (← ssa)
      lit "="
      for (n, cnt) in defs do
        match cnt with
        | some c => for k in List.range c do results := results.push (n ++ "#" ++ toString k)
        | none => results := results.push n
    ws
    if (← peek?) == some '"' then
      bump
      let name ← takeWhile (· != '"')
      bump
      lit "("
      let operands ← sepBy ssaUse ")"
      let mut regions := #[]
      if ← tryLit "(" then regions ← sepBy block ")"
      let attrs ← if (← (do ws; peek?)) == some '{' then attrDict else pure []
      lit ":"
      lit "("
      let ins ← sepBy ty ")"
      lit "->"
      let outs ← tyList
      -- Multi-result ops name their results %w#0 …; single-result keep the bare name.
      let named := if results.size == 1 && outs.size > 1 then
          (List.range outs.size).toArray.map fun k => results[0]! ++ "#" ++ toString k
        else results
      return .mk named name operands attrs regions ins outs
    -- The printed terminators: `func.return %a, %b : T, T` / `return %a : T`.
    let name ← takeWhile isIdChar
    if name == "func.return" || name == "return" || name == "stablehlo.return" then
      let mut operands := #[]
      ws
      if (← peek?) == some '%' then
        operands := #[← ssaUse]
        while ← tryLit "," do operands := operands.push (← ssaUse)
        lit ":"
        discard <| ty
        while ← tryLit "," do discard ty
      return .mk #[] name operands [] #[] #[] #[]
    fail s!"unsupported op syntax {name.quote} (the generic form is expected)"
end

/-- Skip an optional `{…}` attribute dictionary (argument and result attributes). -/
def skipAttrs : P Unit := do
  ws
  if (← peek?) == some '{' then discard attrDict

def func : P Func := do
  lit "func.func"
  discard <| tryLit "public"
  discard <| tryLit "private"
  lit "@"
  let name ← takeWhile isIdChar
  lit "("
  let args ← sepBy (do let n ← ssaUse; lit ":"; let t ← ty; skipAttrs; return (n, t)) ")"
  let mut outs := #[]
  if ← tryLit "->" then
    if ← tryLit "(" then outs ← sepBy (do let t ← ty; skipAttrs; return t) ")"
    else outs := #[← ty]
  if ← tryLit "attributes" then discard attrDict
  let b ← block
  return { name, body := .mk args b.ops b.ret, outTys := outs }

def module : P Module := do
  let wrapped ← tryLit "module"
  if wrapped then
    if ← tryLit "@" then discard <| takeWhile isIdChar
    if ← tryLit "attributes" then discard attrDict
    lit "{"
  let mut fs := #[]
  repeat
    ws
    if ← startsWith "func.func" then fs := fs.push (← func) else break
  if wrapped then lit "}"
  ws
  if (← peek?).isSome then fail "trailing text after the module"
  return { funcs := fs }

def parse (text : String) : Except String Module :=
  (module.run { s := text.toList.toArray }).map (·.1)

end StablehloMlx.Parse
