import StablehloMlx.Kernels.Dsl

/-!
# `StablehloMlx.Kernels.Math` — ggml-cpu's exp and the platform erf, per lane

`ggml_v_expf` restates ggml-cpu's arm64 NEON `ggml_v_expf`
(ggml/src/ggml-cpu/vec.h, "adapted from arm limited optimized routine"), lane
by lane: each `vfmaq_f32(a, b, c)` is `fma(b, c, a)`, each `vfmsq_f32(a, b, c)`
is `fma(-b, c, a)`, every constant is the same binary32 bit pattern. The NEON
code branches on all four lanes at once, but each lane's result depends only on
that lane, so the per-lane form is the same function.

`platform_erff` is the binary32 `erff` that ggml-cpu's `gelu_erf` calls on this
host: macOS libsystem_m (macOS 26.6.2, build 25G83), restated from its arm64
instruction sequence so the GPU computes the same function. Its tiny-argument
branch multiplies in binary64 and narrows (`fcvt d0,s0; fmul d0,d0,d1;
fcvt s0,d0`), which is `f64_mul` then `f64_to_f32` here. The 32-entry, eight
coefficient table is passed in as a buffer (`erffTable`). The port is checked
against the CPU routine on every one of the 2^32 inputs
(`Tests/OpTests.lean`, case `erff_exhaustive`).
-/

namespace StablehloMlx.Kernels.Math

open LeanSlang
open StablehloMlx.Kernels.Dsl

def ggmlVExpf : SlangFunctionDecl :=
  fn fT "ggml_v_expf" [("x", fT)]
    [ let_ fT "r" (fbits 0x4B400000)                                   -- 0x1.8p23f
    , let_ fT "z" (fma (v "x") (fbits 0x3FB8AA3B) (v "r"))             -- r + x·0x1.715476p+0f
    , let_ fT "n" (v "z" - v "r")
    , let_ fT "b" (fma (neg (v "n")) (fbits 0x35BFBE8E)                -- − n·0x1.7f7d1cp-20f
                     (fma (neg (v "n")) (fbits 0x3F317200) (v "x")))   -- x − n·0x1.62e4p-1f
    , let_ uT "e" (asuint (v "z") <<< u 23)
    , let_ fT "k" (asfloat (v "e" + u 0x3F800000))                     -- + bits(1.0f)
    , let_ fT "uu" (v "b" * v "b")
    , let_ fT "p1" (fma (fbits 0x3E2AAF33) (v "b") (fbits 0x3EFFFEDB)) -- 0x1.fffdb6p-2f + 0x1.555e66p-3f·b
    , let_ fT "p2" (fma (fbits 0x3C072010) (v "b") (fbits 0x3D2B9F17)) -- 0x1.573e2ep-5f + 0x1.0e4020p-7f·b
    , let_ fT "p3" (fma (v "p2") (v "uu") (v "p1"))
    , let_ fT "j" (fma (v "p3") (v "uu") (fbits 0x3F7FFFF6 * v "b"))   -- 0x1.ffffecp-1f·b + p3·u
    , let_ fT "an" (call "abs" [v "n"])
    , let_ uT "d" (sel (le (v "n") (fbits 0)) (u 0x82000000) (u 0))
    , let_ fT "s1" (asfloat (v "d" + u 0x7F000000))
    , if_ (gt (v "an") (fbits 0x43400000)) [ ret (v "s1" * v "s1") ]  -- |n| > 192
    , if_ (gt (v "an") (fbits 0x42FC0000))                             -- |n| > 126
        [ let_ fT "s2" (asfloat (v "e" - v "d"))
        , ret (fma (v "s2") (v "j") (v "s2") * v "s1") ]
    , ret (fma (v "k") (v "j") (v "k")) ]

/-- `fmadd d, n, m, a` is `a + n·m` with one rounding. -/
def fmadd (n m a : E) : E := fma n m a

/-- The platform binary32 erf. `tab` holds the 256 coefficients (32 rows of 8). -/
def platformErff : SlangFunctionDecl :=
  fn fT "platform_erff" [("x", fT)]
    [ let_ uT "xb" (asuint (v "x"))
    , let_ uT "w9" (v "xb" &&& u 0x7FFFFFFF)
    , let_ fT "ax" (asfloat (v "w9"))
    , if_ (gt (v "w9" >>> u 23) (u 0xFE))
        -- inf: copysign(1, x). NaN: `fadd s0, s0, s0`, which on arm64 (FPCR.DN
        -- clear) returns the operand quieted, payload kept. The GPU's own add
        -- returns a canonical NaN, so the quieting is written as the bit it sets.
        [ if_ (eq (v "w9") (u 0x7F800000)) [ ret (asfloat ((v "xb" &&& u 0x80000000) ||| u 0x3F800000)) ]
        , ret (asfloat (v "xb" ||| u 0x00400000)) ]
    , if_ (gt (v "w9") (u 0x3E620000))
        [ let_ uT "sg" (v "xb" &&& u 0x80000000)
        , if_ (gt (v "w9") (u 0x407AD4FF))
            [ ret (asfloat (v "sg" ||| asuint (fbits 0x3F800000 - fbits 0x00800000))) ]
        , let_ fT "tt" (v "ax" + fbits 0x49C00000)                     -- + 0x1.8p20
        , let_ fT "nn" (v "tt" + fbits 0xC9C00000)                     -- − 0x1.8p20
        , let_ uT "ix" ((asuint (v "tt") &&& u 0x1F) * u 8)
        , let_ fT "r" (v "ax" - v "nn")
        , let_ fT "r2" (v "r" * v "r")
        , let_ fT "q2" (fmadd (v "r") (at_ "erffTable" (v "ix" + u 7)) (at_ "erffTable" (v "ix" + u 6)))
        , let_ fT "q3" (fmadd (v "r") (at_ "erffTable" (v "ix" + u 5)) (at_ "erffTable" (v "ix" + u 4)))
        , let_ fT "q1" (fmadd (v "r2") (v "q2") (v "q3"))
        , set "q1" (fmadd (v "r") (v "q1") (at_ "erffTable" (v "ix" + u 3)))
        , set "q1" (fmadd (v "r") (v "q1") (at_ "erffTable" (v "ix" + u 1)))
        , let_ fT "q0" (fmadd (v "r") (at_ "erffTable" (v "ix" + u 2)) (v "q1"))
        , set "q0" (at_ "erffTable" (v "ix") + v "q0")
        , ret (asfloat (v "sg" ||| asuint (v "q0"))) ]
    , if_ (gt (v "w9") (u 0x24E69594))
        [ let_ fT "x2" (v "x" * v "x")
        , let_ fT "c" (fmadd (v "x2") (fbits 0xBCD7E8D1) (fbits 0x3DE70F49))
        , set "c" (fmadd (v "x2") (v "c") (fbits 0xBEC0939E))
        , set "c" (fmadd (v "x2") (v "c") (fbits 0xB37CF796))
        , let_ fT "s1" (v "x" * v "c")
        , ret (fmadd (v "x") (fbits 0x3F906EBB) (v "s1")) ]
    -- Tiny |x|: (float)((double)x · 0x3FF20DD750429B6D).
    , ret (call "f64_to_f32" [call "f64_mul" [call "f64_from_f32" [v "x"], ul 0x3FF20DD750429B6D]]) ]

/-- The table `platform_erff` reads: 32 rows of eight binary32 bit patterns,
    row `i` at `8i … 8i+7` (libsystem_m's table, 32-byte stride). Rows 0 and 1
    are never read (|x| > 0.22 gives a row index of at least 2). -/
def erffTable : List UInt32 :=
  [ 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000
  , 0x3F906EBB, 0xB37CF796, 0xBEC0939E, 0x3DE70F49, 0xBCD7E8D1, 0x00000000, 0x00000000, 0x00000000
  , 0x3E8D7AA7, 0x31071D58, 0x3F87AE8B, 0x31053151, 0xBE87AE7F, 0xBE9E4BC8, 0x3E01C86D, 0x3DA44744
  , 0x3ECEE869, 0x32359CC7, 0x3F7AF867, 0xB20EDF8F, 0xBEBC3A3F, 0xBE7083AD, 0x3E2A487B, 0x3D3B1C87
  , 0x3F053F7B, 0xB1FCD1F5, 0x3F60F7E5, 0x32220F91, 0xBEE0F7D7, 0xBE15FAD7, 0x3E3B2CED, 0x3BF6F26C
  , 0x3F1F8CB7, 0xB1CE57EA, 0x3F4374B5, 0xB2B95A55, 0xBEF451D6, 0xBD6408F0, 0x3E3472A5, 0xBCDEDA06
  , 0x3F360E4C, 0xB2A6AC0F, 0x3F249721, 0x32DB254E, 0xBEF6E2AA, 0x3CDB730A, 0x3E1A23AE, 0xBD59528A
  , 0x3F48B925, 0xB2AE6694, 0x3F0655B1, 0xB0D18430, 0xBEEB15F3, 0x3DBE4E83, 0x3DE61165, 0xBD8953A6
  , 0x3F57BB3D, 0x3268638D, 0x3ED488F8, 0x3219A148, 0xBED488FA, 0x3E0DB094, 0x3D8DC033, 0xBD8D73EB
  , 0x3F636D69, 0x3282DA7F, 0x3EA2F4CE, 0xB14DE4F8, 0xBEB7536C, 0x3E2659E0, 0x3CE5E558, 0xBD7AED2F
  , 0x3F6C432F, 0xB24DFBED, 0x3E723298, 0xB12523CF, 0xBE975FA5, 0x3E2B8E80, 0xBBC5C092, 0xBD412E79
  , 0x3F72BB46, 0x31EEA909, 0x3E2E72CB, 0xB0F545D0, 0xBE6FDDE4, 0x3E21BA70, 0xBCF8CA30, 0xBCFADE7F
  , 0x3F7752AB, 0xB28E79D4, 0x3DF391B9, 0x30CBF5AD, 0xBE36AD56, 0x3E0E1509, 0xBD3636BC, 0xBC7444B1
  , 0x3F7A7B4A, 0xB212A005, 0x3DA4CEA4, 0xB0F3C649, 0xBE05E7ED, 0x3DEB31A0, 0xBD4B4ED7, 0xBB0F45C9
  , 0x3F7C9684, 0xB28051DC, 0x3D582A98, 0x2FA224C9, 0xBDBD254F, 0x3DB8A471, 0xBD44D084, 0x3BD77F62
  , 0x3F7DF30F, 0x32EF5EF9, 0x3D09675A, 0xB0876121, 0xBD80D0E9, 0x3D8A1E9A, 0xBD2CFF36, 0x3C3B2D57
  , 0x3F7ECD71, 0xB2BD865D, 0x3CA94DCF, 0x30021367, 0xBD294DD0, 0x3D458583, 0xBD0D13A5, 0x3C560232
  , 0x3F7F5211, 0xB2654545, 0x3C4A3127, 0x2F5AD3A9, 0xBCD6D431, 0x3D075244, 0xBCD80948, 0x3C4C7CA8
  , 0x3F7FA024, 0xB29FDA92, 0x3BEA0A1D, 0x2F16C838, 0xBC83A5A3, 0x3CB1F7B7, 0xBC9C7883, 0x3C2E884A
  , 0x3F7FCCB0, 0x32F3DE59, 0x3B8348C6, 0xAF1B7899, 0xBC1BE64E, 0x3C60F606, 0xBC57793F, 0x3C08F13A
  , 0x3F7FE554, 0x32F4BE5F, 0x3B0EC18C, 0xAEE34698, 0xBBB271BB, 0x3C08CEC6, 0xBC0D898B, 0x3BC8974B
  , 0x3F7FF28A, 0x32BBD2D1, 0x3A96744C, 0x2E222FBC, 0xBB457851, 0x3BA03FC4, 0xBBB1D8F0, 0x3B8A62CA
  , 0x3F7FF968, 0xB21F82FA, 0x3A19B067, 0xADEE5F13, 0xBAD35213, 0x3B34E771, 0xBB5628D8, 0x3B34EF67
  , 0x3F7FFCDD, 0x320413AB, 0x399829C8, 0x2C0B6E1B, 0xBA5ABB67, 0x3AC4F06C, 0xBAF785B2, 0x3AE119EE
  , 0x3F7FFE8D, 0x32C41055, 0x39120475, 0x2C27644F, 0xB9DB05D5, 0x3A4EDB2C, 0xBA89757F, 0x3A85A40D
  , 0x3F7FFF5A, 0xB1227BA0, 0x3887CF0E, 0x2AFD8166, 0xB954327A, 0x39D1B919, 0xBA12DC3F, 0x3A17CB0A
  , 0x3F7FFFB8, 0xB2413260, 0x37F4DAF5, 0x2B67AB17, 0xB8C6F0AF, 0x394D5171, 0xB9970E41, 0x39A53790
  , 0x3F7FFFE2, 0xB2E926AD, 0x3755F051, 0xAAEA5FE4, 0xB8348169, 0x38C22819, 0xB915AE61, 0x392C9150
  , 0x3F7FFFF4, 0xB2EF2AEC, 0x36B52CBA, 0x2A769F3E, 0xB79E85B2, 0x38316553, 0xB88EF8CC, 0x38AD2A32
  , 0x3F7FFFFB, 0x31461D86, 0x3614B53A, 0x27FEFC6E, 0xB706C2C5, 0x379CA455, 0xB803B44B, 0x382718D6
  , 0x3F7FFFFE, 0x31BC5C28, 0x356C9B92, 0x289EB52B, 0xB65DCEFC, 0x3705B3F8, 0xB76A1DFF, 0x379B2D23
  , 0x3F7FFFFF, 0x3292CED0, 0x34B670D8, 0x281539B2, 0xB5B0BAA3, 0x365CAD50, 0xB6C8D73B, 0x370AC6D6 ]

end StablehloMlx.Kernels.Math
