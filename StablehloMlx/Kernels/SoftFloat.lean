import StablehloMlx.Kernels.Dsl

/-!
# `StablehloMlx.Kernels.SoftFloat` — IEEE binary64 on a GPU without doubles

ggml-cpu accumulates several sums in `double` (`ggml_float`): the soft_max
denominator, the norm mean and variance. The Metal GPU has no binary64, so the
kernels carry a binary64 as its bit pattern in a `uint64_t` and do the arithmetic
in integers, rounding to nearest even exactly as the CPU's FPU does.

Only the operations those sums need are here: widen from binary32 and from
uint32, add, multiply, divide, narrow to binary32. Binary32 division and square
root are also here, because a GPU's own `/` and `sqrt` need not be correctly
rounded and ggml-cpu's are (IEEE 754 on arm64).

binary32 division is done in binary64 and narrowed: for `/` the double rounding
is innocuous because 53 ≥ 2·24 + 2 (Figueroa, "When is double rounding
innocuous?", SIGNUM 1995).

Layout used throughout: a working mantissa `m` holds the hidden bit at bit 61,
so nine bits sit below the binary64 mantissa for rounding (two rounding bits
and a sticky region).
-/

namespace StablehloMlx.Kernels.SoftFloat

open LeanSlang
open StablehloMlx.Kernels.Dsl

/-- 2^52 − 1, the binary64 fraction mask. -/
def FRAC : E := ul 0xFFFFFFFFFFFFF
def HIDDEN : E := ul 0x10000000000000
def INF64 : E := ul 0x7FF0000000000000
/-- The arm64 default NaN (FPCR.DN clear propagates the operand; this is used
    only for invalid operations, where arm64 returns the default NaN). -/
def NAN64 : E := ul 0x7FF8000000000000

/-- Index of the highest set bit of a nonzero 64-bit value. -/
def hibit64 : SlangFunctionDecl :=
  fn iT "hibit64" [("x", lT)]
    [ let_ uT "hi" (toU (v "x" >>> ul 32))
    , if_ (ne (v "hi") (u 0)) [ ret (toI (call "firstbithigh" [v "hi"]) + .litInt 32) ]
    , ret (toI (call "firstbithigh" [toU (v "x" &&& ul 0xFFFFFFFF)])) ]

/-- `x >> n`, with every shifted-out bit ORed into bit 0 (the sticky bit). -/
def srs : SlangFunctionDecl :=
  fn lT "srs" [("x", lT), ("n", uT)]
    [ if_ (eq (v "n") (u 0)) [ ret (v "x") ]
    , if_ (ge (v "n") (u 63)) [ ret (sel (ne (v "x") (ul 0)) (ul 1) (ul 0)) ]
    , let_ lT "lost" (v "x" &&& ((ul 1 <<< toL (v "n")) - ul 1))
    , ret ((v "x" >>> toL (v "n")) ||| sel (ne (v "lost") (ul 0)) (ul 1) (ul 0)) ]

/-- Round to nearest even and pack. `m` has its leading one at bit 61 (or is a
    subnormal-range value with `e` = 1 after the shift below); the value is
    `m · 2^(e − 1023 − 61)`. -/
def pack64 : SlangFunctionDecl :=
  fn lT "pack64" [("s", lT), ("e0", iT), ("m0", lT)]
    [ let_ iT "e" (v "e0")
    , let_ lT "m" (v "m0")
    , if_ (lt (v "e") (.litInt 1))
        [ set "m" (call "srs" [v "m", toU (.litInt 1 - v "e")]), set "e" (.litInt 1) ]
    , let_ lT "rem" (v "m" &&& ul 0x1FF)
    , set "m" (v "m" >>> ul 9)
    , if_ (or_ (gt (v "rem") (ul 0x100)) (and_ (eq (v "rem") (ul 0x100)) (ne (v "m" &&& ul 1) (ul 0))))
        [ set "m" (v "m" + ul 1) ]
    , if_ (ne (v "m" >>> ul 53) (ul 0)) [ set "m" (v "m" >>> ul 1), set "e" (v "e" + .litInt 1) ]
    , if_ (ge (v "e") (.litInt 2047)) [ ret ((v "s" <<< ul 63) ||| INF64) ]
    , let_ lT "field" (sel (ne (v "m" >>> ul 52) (ul 0)) (toL (v "e")) (ul 0))
    , ret ((v "s" <<< ul 63) ||| (v "field" <<< ul 52) ||| (v "m" &&& FRAC)) ]

/-- Exact widening, binary32 → binary64 (subnormals normalised). -/
def f64FromF32 : SlangFunctionDecl :=
  fn lT "f64_from_f32" [("x", fT)]
    [ let_ uT "b" (asuint (v "x"))
    , let_ lT "s" (toL (v "b" >>> u 31))
    , let_ uT "e" ((v "b" >>> u 23) &&& u 0xFF)
    , let_ uT "f" (v "b" &&& u 0x7FFFFF)
    , if_ (eq (v "e") (u 0xFF)) [ ret ((v "s" <<< ul 63) ||| INF64 ||| (toL (v "f") <<< ul 29)) ]
    , if_ (eq (v "e") (u 0))
        [ if_ (eq (v "f") (u 0)) [ ret (v "s" <<< ul 63) ]
        , let_ uT "p" (call "firstbithigh" [v "f"])
        , ret ((v "s" <<< ul 63) ||| (toL (v "p" + u 874) <<< ul 52)
                ||| ((toL (v "f") <<< toL (u 52 - v "p")) &&& FRAC)) ]
    , ret ((v "s" <<< ul 63) ||| (toL (v "e" + u 896) <<< ul 52) ||| (toL (v "f") <<< ul 29)) ]

/-- Exact widening, uint32 → binary64. -/
def f64FromU32 : SlangFunctionDecl :=
  fn lT "f64_from_u32" [("n", uT)]
    [ if_ (eq (v "n") (u 0)) [ ret (ul 0) ]
    , let_ uT "p" (call "firstbithigh" [v "n"])
    , ret ((toL (v "p" + u 1023) <<< ul 52) ||| ((toL (v "n") <<< toL (u 52 - v "p")) &&& FRAC)) ]

/-- Round to nearest even, binary64 → binary32, with binary32 subnormals. -/
def f64ToF32 : SlangFunctionDecl :=
  fn fT "f64_to_f32" [("d", lT)]
    [ let_ uT "s" (toU (v "d" >>> ul 63))
    , let_ iT "e" (toI ((v "d" >>> ul 52) &&& ul 0x7FF))
    , let_ lT "f" (v "d" &&& FRAC)
    , if_ (eq (v "e") (.litInt 0x7FF))
        [ ret (asfloat ((v "s" <<< u 31) ||| u 0x7F800000
            ||| sel (ne (v "f") (ul 0)) (u 0x400000 ||| toU (v "f" >>> ul 29)) (u 0))) ]
    , if_ (and_ (eq (v "e") (.litInt 0)) (eq (v "f") (ul 0))) [ ret (asfloat (v "s" <<< u 31)) ]
    , let_ lT "m" (v "f" ||| sel (ne (v "e") (.litInt 0)) HIDDEN (ul 0))
    , if_ (eq (v "e") (.litInt 0)) [ set "e" (.litInt 1) ]
    , let_ iT "ef" (v "e" - .litInt 896)
    , let_ uT "sh" (u 29)
    , if_ (le (v "ef") (.litInt 0))
        [ set "sh" (toU (.litInt 30 - v "ef")), set "ef" (.litInt 0) ]
    , if_ (gt (v "sh") (u 63)) [ set "sh" (u 63) ]
    , let_ lT "q" (v "m" >>> toL (v "sh"))
    , let_ lT "rem" (v "m" &&& ((ul 1 <<< toL (v "sh")) - ul 1))
    , let_ lT "half" (ul 1 <<< toL (v "sh" - u 1))
    , if_ (or_ (gt (v "rem") (v "half")) (and_ (eq (v "rem") (v "half")) (ne (v "q" &&& ul 1) (ul 0))))
        [ set "q" (v "q" + ul 1) ]
    -- Subnormal range: a carry into bit 23 is exactly the smallest normal's pattern.
    , if_ (eq (v "ef") (.litInt 0)) [ ret (asfloat ((v "s" <<< u 31) ||| toU (v "q"))) ]
    , if_ (ne (v "q" >>> ul 24) (ul 0)) [ set "q" (v "q" >>> ul 1), set "ef" (v "ef" + .litInt 1) ]
    , if_ (ge (v "ef") (.litInt 255)) [ ret (asfloat ((v "s" <<< u 31) ||| u 0x7F800000)) ]
    , ret (asfloat ((v "s" <<< u 31) ||| (toU (v "ef") <<< u 23) ||| toU (v "q" &&& ul 0x7FFFFF))) ]

/-- Unpack a finite binary64 into a working mantissa (hidden bit at 52,
    subnormals normalised) and an unbiased-plus-1023 exponent. -/
def unpackStmts (p : String) : List S :=
  [ let_ iT (p ++ "e") (toI ((v p >>> ul 52) &&& ul 0x7FF))
  , let_ lT (p ++ "m") (v p &&& FRAC)
  , if_ (eq (v (p ++ "e")) (.litInt 0))
      [ let_ iT (p ++ "h") (call "hibit64" [v (p ++ "m")])
      , set (p ++ "m") (v (p ++ "m") <<< toL (.litInt 52 - v (p ++ "h")))
      , set (p ++ "e") (.litInt 1 - (.litInt 52 - v (p ++ "h"))) ]
      [ set (p ++ "m") (v (p ++ "m") ||| HIDDEN) ] ]

def isNan (x : E) : E := gt (x &&& ul 0x7FFFFFFFFFFFFFFF) INF64
def isInf (x : E) : E := eq (x &&& ul 0x7FFFFFFFFFFFFFFF) INF64
def isZero (x : E) : E := eq (x &&& ul 0x7FFFFFFFFFFFFFFF) (ul 0)

/-- binary64 addition, round to nearest even. -/
def f64Add : SlangFunctionDecl :=
  fn lT "f64_add" [("a", lT), ("b", lT)]
    ([ if_ (isNan (v "a")) [ ret (v "a" ||| ul 0x8000000000000) ]
     , if_ (isNan (v "b")) [ ret (v "b" ||| ul 0x8000000000000) ]
     , if_ (isInf (v "a"))
         [ if_ (and_ (isInf (v "b")) (ne (v "a") (v "b"))) [ ret NAN64 ], ret (v "a") ]
     , if_ (isInf (v "b")) [ ret (v "b") ]
     , if_ (isZero (v "a"))
         [ if_ (isZero (v "b")) [ ret (v "a" &&& v "b") ], ret (v "b") ]
     , if_ (isZero (v "b")) [ ret (v "a") ]
     , let_ lT "sa" (v "a" >>> ul 63)
     , let_ lT "sb" (v "b" >>> ul 63) ]
     ++ unpackStmts "a" ++ unpackStmts "b" ++
     [ set "am" (v "am" <<< ul 9)
     , set "bm" (v "bm" <<< ul 9)
     -- Larger magnitude first.
     , if_ (or_ (lt (v "ae") (v "be")) (and_ (eq (v "ae") (v "be")) (lt (v "am") (v "bm"))))
         [ let_ iT "te" (v "ae"), set "ae" (v "be"), set "be" (v "te")
         , let_ lT "tm" (v "am"), set "am" (v "bm"), set "bm" (v "tm")
         , let_ lT "ts" (v "sa"), set "sa" (v "sb"), set "sb" (v "ts") ]
     , set "bm" (call "srs" [v "bm", toU (v "ae" - v "be")])
     , let_ lT "m" (sel (eq (v "sa") (v "sb")) (v "am" + v "bm") (v "am" - v "bm"))
     -- x + (−x) is +0 under round to nearest.
     , if_ (eq (v "m") (ul 0)) [ ret (ul 0) ]
     , let_ iT "e" (v "ae")
     , let_ iT "h" (call "hibit64" [v "m"])
     , if_ (gt (v "h") (.litInt 61))
         [ set "m" (call "srs" [v "m", u 1]), set "e" (v "e" + .litInt 1) ]
         [ set "m" (v "m" <<< toL (.litInt 61 - v "h")), set "e" (v "e" - (.litInt 61 - v "h")) ]
     , ret (call "pack64" [v "sa", v "e", v "m"]) ])

/-- binary64 multiplication, round to nearest even (finite operands; the
    callers pass finite values only, and a non-finite operand returns NaN so
    the gap shows rather than hides). -/
def f64Mul : SlangFunctionDecl :=
  fn lT "f64_mul" [("a", lT), ("b", lT)]
    ([ let_ lT "s" ((v "a" ^^^ v "b") >>> ul 63)
     , if_ (or_ (gt (v "a" &&& ul 0x7FFFFFFFFFFFFFFF) (ul 0x7FEFFFFFFFFFFFFF))
                (gt (v "b" &&& ul 0x7FFFFFFFFFFFFFFF) (ul 0x7FEFFFFFFFFFFFFF))) [ ret NAN64 ]
     , if_ (or_ (isZero (v "a")) (isZero (v "b"))) [ ret (v "s" <<< ul 63) ] ]
     ++ unpackStmts "a" ++ unpackStmts "b" ++
     [ let_ lT "a0" (v "am" &&& ul 0xFFFFFFFF), let_ lT "a1" (v "am" >>> ul 32)
     , let_ lT "b0" (v "bm" &&& ul 0xFFFFFFFF), let_ lT "b1" (v "bm" >>> ul 32)
     , let_ lT "p00" (v "a0" * v "b0"), let_ lT "p01" (v "a0" * v "b1")
     , let_ lT "p10" (v "a1" * v "b0"), let_ lT "p11" (v "a1" * v "b1")
     , let_ lT "mid" ((v "p00" >>> ul 32) + (v "p01" &&& ul 0xFFFFFFFF) + (v "p10" &&& ul 0xFFFFFFFF))
     , let_ lT "lo" ((v "p00" &&& ul 0xFFFFFFFF) ||| (v "mid" <<< ul 32))
     , let_ lT "hi" (v "p11" + (v "p01" >>> ul 32) + (v "p10" >>> ul 32) + (v "mid" >>> ul 32))
     -- The 106-bit product has its leading one at bit 104 or 105; bring bit 104 to 61.
     , let_ lT "m" ((v "hi" <<< ul 21) ||| (v "lo" >>> ul 43)
                    ||| sel (ne (v "lo" &&& ul 0x7FFFFFFFFFF) (ul 0)) (ul 1) (ul 0))
     , let_ iT "e" (v "ae" + v "be" - .litInt 1023)
     , if_ (ne (v "m" >>> ul 62) (ul 0)) [ set "m" (call "srs" [v "m", u 1]), set "e" (v "e" + .litInt 1) ]
     , ret (call "pack64" [v "s", v "e", v "m"]) ])

/-- binary64 division, round to nearest even, by restoring long division. -/
def f64Div : SlangFunctionDecl :=
  fn lT "f64_div" [("a", lT), ("b", lT)]
    ([ let_ lT "s" ((v "a" ^^^ v "b") >>> ul 63)
     , if_ (isNan (v "a")) [ ret (v "a" ||| ul 0x8000000000000) ]
     , if_ (isNan (v "b")) [ ret (v "b" ||| ul 0x8000000000000) ]
     , if_ (isInf (v "a")) [ if_ (isInf (v "b")) [ ret NAN64 ], ret ((v "s" <<< ul 63) ||| INF64) ]
     , if_ (isInf (v "b")) [ ret (v "s" <<< ul 63) ]
     , if_ (isZero (v "b")) [ if_ (isZero (v "a")) [ ret NAN64 ], ret ((v "s" <<< ul 63) ||| INF64) ]
     , if_ (isZero (v "a")) [ ret (v "s" <<< ul 63) ] ]
     ++ unpackStmts "a" ++ unpackStmts "b" ++
     [ let_ iT "e" (v "ae" - v "be" + .litInt 1023)
     , if_ (lt (v "am") (v "bm")) [ set "am" (v "am" <<< ul 1), set "e" (v "e" - .litInt 1) ]
     -- 55 quotient bits: 53 for the mantissa and two to round on, plus a sticky remainder.
     , let_ lT "r" (v "am"), let_ lT "q" (ul 0)
     , for_ "i" (u 0) (u 55)
         [ set "q" (v "q" <<< ul 1)
         , if_ (ge (v "r") (v "bm")) [ set "r" (v "r" - v "bm"), set "q" (v "q" ||| ul 1) ]
         , set "r" (v "r" <<< ul 1) ]
     , let_ lT "m" ((v "q" <<< ul 7) ||| sel (ne (v "r") (ul 0)) (ul 1) (ul 0))
     , ret (call "pack64" [v "s", v "e", v "m"]) ])

/-- binary32 division, correctly rounded (binary64 quotient, then narrowed). -/
def f32Div : SlangFunctionDecl :=
  fn fT "f32_div" [("a", fT), ("b", fT)]
    [ ret (call "f64_to_f32" [call "f64_div" [call "f64_from_f32" [v "a"], call "f64_from_f32" [v "b"]]]) ]

/-- binary32 square root, correctly rounded, by integer square root. -/
def f32Sqrt : SlangFunctionDecl :=
  fn fT "f32_sqrt" [("x", fT)]
    [ let_ uT "b" (asuint (v "x"))
    , if_ (eq (v "b" &&& u 0x7FFFFFFF) (u 0)) [ ret (v "x") ]
    , if_ (ne (v "b" >>> u 31) (u 0)) [ ret (asfloat (u 0x7FC00000)) ]
    , if_ (ge (v "b") (u 0x7F800000)) [ ret (v "x") ]
    , let_ iT "e" (toI (v "b" >>> u 23))
    , let_ uT "m" (v "b" &&& u 0x7FFFFF)
    , if_ (eq (v "e") (.litInt 0))
        [ let_ iT "p" (toI (call "firstbithigh" [v "m"]))
        , set "m" (v "m" <<< toU (.litInt 23 - v "p"))
        , set "e" (.litInt 1 - (.litInt 23 - v "p")) ]
        [ set "m" (v "m" ||| u 0x800000) ]
    -- x = m · 2^(e − 150); make the exponent even so the root's exponent is exact.
    , let_ iT "k" (v "e" - .litInt 150)
    , let_ lT "w" (toL (v "m"))
    , if_ (ne (v "k" &&& .litInt 1) (.litInt 0)) [ set "w" (v "w" <<< ul 1), set "k" (v "k" - .litInt 1) ]
    -- w < 2^25; shift by 38 so the root has 25 or 26 bits (24 + round + sticky).
    , set "w" (v "w" <<< ul 38)
    , set "k" (v "k" - .litInt 38)
    , let_ lT "r" (ul 0), let_ lT "rem" (ul 0)
    , for_ "i" (u 0) (u 32)
        [ set "rem" ((v "rem" <<< ul 2) ||| ((v "w" >>> ul 62) &&& ul 3))
        , set "w" (v "w" <<< ul 2)
        , let_ lT "t" ((v "r" <<< ul 2) ||| ul 1)
        , set "r" (v "r" <<< ul 1)
        , if_ (ge (v "rem") (v "t")) [ set "rem" (v "rem" - v "t"), set "r" (v "r" ||| ul 1) ] ]
    -- sqrt(x) = r · 2^(k/2), r has its leading one at bit 31 or 32 − 1.
    , let_ iT "h" (call "hibit64" [v "r"])
    , let_ iT "sh" (v "h" - .litInt 23)
    , let_ lT "q" (v "r" >>> toL (v "sh"))
    , let_ lT "lost" (v "r" &&& ((ul 1 <<< toL (v "sh")) - ul 1))
    , let_ lT "half" (ul 1 <<< toL (v "sh" - .litInt 1))
    , let_ bT "sticky" (or_ (ne (v "rem") (ul 0)) (ne (v "lost" &&& (v "half" - ul 1)) (ul 0)))
    , if_ (and_ (ne (v "lost" &&& v "half") (ul 0)) (or_ (v "sticky") (ne (v "q" &&& ul 1) (ul 0))))
        [ set "q" (v "q" + ul 1) ]
    , let_ iT "ee" ((v "k" / .litInt 2) + v "sh" + .litInt 150)
    , if_ (ne (v "q" >>> ul 24) (ul 0)) [ set "q" (v "q" >>> ul 1), set "ee" (v "ee" + .litInt 1) ]
    , ret (asfloat ((toU (v "ee") <<< u 23) ||| toU (v "q" &&& ul 0x7FFFFF))) ]

/-- Every helper, in dependency order. -/
def all : List SlangFunctionDecl :=
  [hibit64, srs, pack64, f64FromF32, f64FromU32, f64ToF32, f64Add, f64Mul, f64Div, f32Div, f32Sqrt]

end StablehloMlx.Kernels.SoftFloat
