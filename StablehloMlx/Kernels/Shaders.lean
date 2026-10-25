import StablehloMlx.Kernels.SoftFloat
import StablehloMlx.Kernels.Math

/-!
# `StablehloMlx.Kernels.Shaders` — the exact kernels, one Slang module each

Each kernel restates one ggml-cpu (arm64, NEON, no SVE) routine in the order it
accumulates, so the Metal GPU returns the same bits. Sources, all in
ggml/src/ggml-cpu at the pinned ggml:

* `mul_mat`  — `ggml_vec_dot_f32` (vec.cpp): four `float32x4_t` accumulators
  over blocks of 16 (`GGML_F32_STEP` 16, `GGML_F32_EPR` 4, simd-mappings.h),
  `vfmaq_f32`; `GGML_F32x4_REDUCE`; `vaddvq_f32`; then the tail
  `sumf += x[i]*y[i]` in the form clang compiles it (see the kernel).
* `soft_max` — `ggml_compute_forward_soft_max_f32` (ops.cpp) with
  `ggml_vec_soft_max_f32` (vec.cpp): `ggml_v_expf` four lanes at a time, each
  group's `vaddvq_f32` added to a `double`, `1.0/sum` in `double`, then a
  binary32 scale.
* `norm`     — `ggml_compute_forward_norm_f32` built without Accelerate:
  `ggml_vec_sum_f32` (a `double` sum), `ggml_vec_cvar_f32` (`double` sum of
  four-lane `vaddvq_f32` groups, then `/n` in `double`), `1.0f/sqrtf(var+eps)`.
* `silu`     — `ggml_vec_silu_f32`: `x / (1 + ggml_v_expf(0 - x))` on the
  four-lane body.
* `gelu_erf` — `ggml_vec_gelu_erf_f32` (vec.h): `0.5f*x*(1.0f + erff(x*SQRT_2_INV))`.

`vaddvq_f32` is `(v0 + v1) + (v2 + v3)`: clang lowers it to two `faddp`
(pairwise) instructions.
-/

namespace StablehloMlx.Kernels.Shaders

open LeanSlang
open StablehloMlx.Kernels.Dsl

def helpers : List SlangFunctionDecl :=
  SoftFloat.all ++ [Math.ggmlVExpf]

/-- `(v0 + v1) + (v2 + v3)`, the `vaddvq_f32` order. -/
def vaddv (a b c d : E) : E := (a + b) + (c + d)

def ONE64 : E := ul 0x3FF0000000000000

/-- Global thread index and the early exit past the last output. -/
def tidGuard (count : E) : List S :=
  [ let_ uT "t" (.member (v "tid") "x"), if_ (ge (v "t") count) [ retv ] ]

/-! ## mul_mat

Bindings: 0 `w` (rows of K), 1 `x` (rows of K), 2 `p` = [K, M, R, wBatchStride,
N, plain], 3 `y`. Output `y[r·M + m] = dot(w row (r / N)·wBatchStride + m, x row r)`:
the ggml `[M, N, B]` result of `ggml_mul_mat(w, x)`. `plain` = 1 selects the
planted wrong lowering (sequential binary32 sum, no fused multiply-add). -/
def acc (i : Nat) : String := "a" ++ toString i

def mulMat : SlangShaderModule :=
  let K := at_ "p" (u 0)
  let M := at_ "p" (u 1)
  let R := at_ "p" (u 2)
  { globals := [roF "w" 0, roF "x" 1, roU "p" 2, rwF "y" 3]
    functions := helpers ++ [entry 64
      (tidGuard (R * M) ++
      [ let_ uT "r" (v "t" / M), let_ uT "m" (v "t" % M)
      , let_ uT "wb" ((v "r" / at_ "p" (u 4)) * at_ "p" (u 3) + v "m" * K)
      , let_ uT "xb" (v "r" * K)
      , if_ (ne (at_ "p" (u 5)) (u 0))
          [ let_ fT "s" (fbits 0)
          , for_ "i" (u 0) K [ set "s" (v "s" + at_ "w" (v "wb" + v "i") * at_ "x" (v "xb" + v "i")) ]
          , setAt "y" (v "t") (v "s"), retv ] ]
      ++ (List.range 16).map (fun i => let_ fT (acc i) (fbits 0)) ++
      [ let_ uT "np" (K &&& (u 0xFFFFFFF0))
      , for_ "blk" (u 0) (v "np" / u 16)
          ([ let_ uT "i" (v "blk" * u 16) ] ++
           (List.range 16).map fun j =>
             set (acc j) (fma (at_ "w" (v "wb" + v "i" + u j)) (at_ "x" (v "xb" + v "i" + u j)) (v (acc j)))) ]
      -- GGML_F32x4_REDUCE with GGML_F32_ARR = 4: sum[0] += sum[2], sum[1] += sum[3]; sum[0] += sum[1].
      ++ (List.range 4).map (fun l => set (acc l) (v (acc l) + v (acc (8 + l))))
      ++ (List.range 4).map (fun l => set (acc (4 + l)) (v (acc (4 + l)) + v (acc (12 + l))))
      ++ (List.range 4).map (fun l => set (acc l) (v (acc l) + v (acc (4 + l)))) ++
      [ let_ fT "sumf" (vaddv (v (acc 0)) (v (acc 1)) (v (acc 2)) (v (acc 3)))
      -- The tail as clang compiles it (the disassembly of ggml_vec_dot_f32 in
      -- libggml-cpu.a): with 4 or more leftovers, groups of four are vectorised
      -- as separate products (fmul.4s) added one lane at a time, in order; the
      -- last (tail mod 4), or a tail of 1-3, is a scalar fmadd loop.
      , let_ uT "tl" (K - v "np")
      , let_ uT "nq" (sel (ge (v "tl") (u 4)) (v "tl" &&& u 0xFFFFFFFC) (u 0))
      , for_ "i" (v "np") (v "np" + v "nq")
          [ let_ fT "pr" (at_ "w" (v "wb" + v "i") * at_ "x" (v "xb" + v "i"))
          , set "sumf" (v "sumf" + v "pr") ]
      , for_ "i" (v "np" + v "nq") K
          [ set "sumf" (fma (at_ "w" (v "wb" + v "i")) (at_ "x" (v "xb" + v "i")) (v "sumf")) ]
      , setAt "y" (v "t") (v "sumf") ])] }

/-! ## soft_max

Bindings: 0 `x`, 1 `p` = [ncols, rows, scale bits, floatSum], 2 `y`. One thread
per row. `ncols` must be a multiple of 4: ggml-cpu sends a row's last
`ncols mod 4` elements through the platform `expf`, which is not carried
(the lowering refuses such a row). `floatSum` = 1 selects the planted wrong
lowering (the denominator summed in binary32). -/
def softMax : SlangShaderModule :=
  let N := at_ "p" (u 0)
  { globals := [roF "x" 0, roU "p" 1, rwF "y" 2]
    functions := helpers ++ [entry 64
      (tidGuard (at_ "p" (u 1)) ++
      [ let_ uT "o" (v "t" * N)
      , let_ fT "sc" (asfloat (at_ "p" (u 2)))
      , let_ fT "mx" (asfloat (u 0xFF800000))
      , for_ "i" (u 0) N
          [ let_ fT "wv" (at_ "x" (v "o" + v "i") * v "sc")
          , set "mx" (sel (gt (v "mx") (v "wv")) (v "mx") (v "wv")) ]
      , let_ lT "sum" (ul 0)
      , let_ fT "fs" (fbits 0)
      , for_ "g" (u 0) (N / u 4)
          ([ let_ uT "i" (v "o" + v "g" * u 4) ] ++
           (List.range 4).map (fun l =>
             let_ fT ("e" ++ toString l) (call "ggml_v_expf" [at_ "x" (v "i" + u l) * v "sc" - v "mx"])) ++
           (List.range 4).map (fun l => setAt "y" (v "i" + u l) (v ("e" ++ toString l))) ++
           [ let_ fT "part" (vaddv (v "e0") (v "e1") (v "e2") (v "e3"))
           , set "sum" (call "f64_add" [v "sum", call "f64_from_f32" [v "part"]])
           , set "fs" (v "fs" + v "part") ])
      , let_ fT "inv" (call "f64_to_f32" [call "f64_div" [ONE64, v "sum"]])
      , if_ (ne (at_ "p" (u 3)) (u 0)) [ set "inv" (fbits 0x3F800000 / v "fs") ]
      , for_ "i" (u 0) N [ setAt "y" (v "o" + v "i") (at_ "y" (v "o" + v "i") * v "inv") ] ])] }

/-! ## norm

Bindings: 0 `x`, 1 `p` = [ncols, rows, eps bits, gpuOps], 2 `y`. One thread per
row. `gpuOps` = 1 selects the planted wrong lowering (binary32 sums and the
GPU's own `/` and `sqrt`). -/
def norm : SlangShaderModule :=
  let N := at_ "p" (u 0)
  { globals := [roF "x" 0, roU "p" 1, rwF "y" 2]
    functions := helpers ++ [entry 64
      (tidGuard (at_ "p" (u 1)) ++
      [ let_ uT "o" (v "t" * N)
      , let_ fT "eps" (asfloat (at_ "p" (u 2)))
      , if_ (ne (at_ "p" (u 3)) (u 0))
          [ let_ fT "s" (fbits 0)
          , for_ "i" (u 0) N [ set "s" (v "s" + at_ "x" (v "o" + v "i")) ]
          , let_ fT "mean" (v "s" / toF N)
          , let_ fT "s2" (fbits 0)
          , for_ "i" (u 0) N
              [ let_ fT "d" (at_ "x" (v "o" + v "i") - v "mean"), set "s2" (v "s2" + v "d" * v "d") ]
          , let_ fT "scl" (fbits 0x3F800000 / call "sqrt" [v "s2" / toF N + v "eps"])
          , for_ "i" (u 0) N [ setAt "y" (v "o" + v "i") ((at_ "x" (v "o" + v "i") - v "mean") * v "scl") ]
          , retv ]
      -- ggml_vec_sum_f32 without Accelerate: a double sum, narrowed.
      , let_ lT "sum" (ul 0)
      , for_ "i" (u 0) N [ set "sum" (call "f64_add" [v "sum", call "f64_from_f32" [at_ "x" (v "o" + v "i")]]) ]
      , let_ fT "mean" (call "f32_div" [call "f64_to_f32" [v "sum"], toF N])
      -- ggml_vec_cvar_f32: four-lane groups, then the scalar tail.
      , let_ lT "s2" (ul 0)
      , let_ uT "nb" (N &&& u 0xFFFFFFFC)
      , for_ "g" (u 0) (v "nb" / u 4)
          ([ let_ uT "i" (v "o" + v "g" * u 4) ] ++
           (List.range 4).map (fun l =>
             let_ fT ("d" ++ toString l) (at_ "x" (v "i" + u l) - v "mean")) ++
           (List.range 4).map (fun l => let_ fT ("q" ++ toString l) (v ("d" ++ toString l) * v ("d" ++ toString l))) ++
           [ set "s2" (call "f64_add" [v "s2", call "f64_from_f32" [vaddv (v "q0") (v "q1") (v "q2") (v "q3")]]) ])
      , for_ "i" (v "nb") N
          [ let_ fT "d" (at_ "x" (v "o" + v "i") - v "mean")
          , let_ fT "q" (v "d" * v "d")
          , set "s2" (call "f64_add" [v "s2", call "f64_from_f32" [v "q"]]) ]
      , let_ fT "var" (call "f64_to_f32" [call "f64_div" [v "s2", call "f64_from_u32" [N]]])
      , let_ fT "scl" (call "f32_div" [fbits 0x3F800000, call "f32_sqrt" [v "var" + v "eps"]])
      , for_ "i" (u 0) N [ setAt "y" (v "o" + v "i") ((at_ "x" (v "o" + v "i") - v "mean") * v "scl") ] ])] }

/-! ## silu

Bindings: 0 `x`, 1 `p` = [count, gpuOps], 2 `y`. `gpuOps` = 1 selects the
planted wrong lowering (the GPU's own `exp` and `/`). -/
def silu : SlangShaderModule :=
  { globals := [roF "x" 0, roU "p" 1, rwF "y" 2]
    functions := helpers ++ [entry 64
      (tidGuard (at_ "p" (u 0)) ++
      [ let_ fT "xv" (at_ "x" (v "t"))
      , if_ (ne (at_ "p" (u 1)) (u 0))
          [ setAt "y" (v "t") (v "xv" / (fbits 0x3F800000 + call "exp" [neg (v "xv")])), retv ]
      , setAt "y" (v "t") (call "f32_div" [v "xv", fbits 0x3F800000 + call "ggml_v_expf" [fbits 0 - v "xv"]]) ])] }

/-! ## gelu_erf

Bindings: 0 `x`, 1 `erffTable`, 2 `p` = [count, gpuErf], 3 `y`. `gpuErf` = 1
selects the planted wrong lowering (GELU's tanh form, SQRT_2_OVER_PI and
GELU_COEF_A from vec.h, in place of erf). -/
def geluErf : SlangShaderModule :=
  { globals := [roF "x" 0, roF "erffTable" 1, roU "p" 2, rwF "y" 3]
    functions := helpers ++ [Math.platformErff, entry 64
      (tidGuard (at_ "p" (u 0)) ++
      [ let_ fT "xv" (at_ "x" (v "t"))
      , let_ fT "ev" (call "platform_erff" [v "xv" * fbits 0x3F3504F3])   -- SQRT_2_INV
      -- Planted: the tanh form of GELU (ggml_gelu_f32's formula), a different function.
      , if_ (ne (at_ "p" (u 1)) (u 0))
          [ set "ev" (call "tanh" [fbits 0x3F4C422A * v "xv" * (fbits 0x3F800000 + fbits 0x3D372713 * v "xv" * v "xv")]) ]
      , setAt "y" (v "t") ((fbits 0x3F000000 * v "xv") * (fbits 0x3F800000 + v "ev"))
      -- A NaN input: every arm64 step returns the input quieted, payload kept
      -- (FPCR.DN clear); the GPU's arithmetic would return a canonical NaN.
      , if_ (gt (asuint (v "xv") &&& u 0x7FFFFFFF) (u 0x7F800000))
          [ setAt "y" (v "t") (asfloat (asuint (v "xv") ||| u 0x00400000)) ] ])] }

/-! ## erff_map — the exhaustive-check kernel: `y[t] = bits(platform_erff(bits⁻¹(base + t)))`.

Bindings: 0 `erffTable`, 1 `p` = [base, count], 2 `y` (uint). -/
def erffMap : SlangShaderModule :=
  { globals := [roF "erffTable" 0, roU "p" 1, rwU "y" 2]
    functions := helpers ++ [Math.platformErff, entry 256
      (tidGuard (at_ "p" (u 1)) ++
      [ setAt "y" (v "t") (asuint (call "platform_erff" [asfloat (at_ "p" (u 0) + v "t")])) ])] }

/-! ## Elementwise binary32 `/` and `sqrt`, correctly rounded.

Bindings: 0 `a`, 1 `b`, 2 `p` = [count], 3 `y` (sqrt ignores `b`). -/
def divide : SlangShaderModule :=
  { globals := [roF "a" 0, roF "b" 1, roU "p" 2, rwF "y" 3]
    functions := helpers ++ [entry 256
      (tidGuard (at_ "p" (u 0)) ++ [ setAt "y" (v "t") (call "f32_div" [at_ "a" (v "t"), at_ "b" (v "t")]) ])] }

def sqrt : SlangShaderModule :=
  { globals := [roF "a" 0, roU "p" 1, rwF "y" 2]
    functions := helpers ++ [entry 256
      (tidGuard (at_ "p" (u 0)) ++ [ setAt "y" (v "t") (call "f32_sqrt" [at_ "a" (v "t")]) ])] }

/-- Every kernel by name, as `emit_kernels` writes them. -/
def all : List (String × SlangShaderModule) :=
  [ ("mul_mat", mulMat), ("soft_max", softMax), ("norm", norm), ("silu", silu)
  , ("gelu_erf", geluErf), ("erff_map", erffMap), ("divide", divide), ("sqrt", sqrt) ]

end StablehloMlx.Kernels.Shaders
