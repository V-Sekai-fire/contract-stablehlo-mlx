# Ops, paths and status

Every case is checked by `Tests/OpTests.lean` on this Mac's GPU (Apple M2 Pro)
against `ref/build.sh`'s ggml-cpu: V-Sekai-fire/ggml 29cae86, arm64 NEON,
`GGML_ACCELERATE=OFF`, one op per case. "Exact" means 0 differing words, both
traced under `mx::compile` and uncompiled. Each case's planted wrong lowering
must give different bits; every planted fault below is caught.

## The table

| ggml op | StableHLO | Path | Status | Planted fault |
|---|---|---|---|---|
| `mul_mat` | `dot_general` | kernel `mul_mat`: `ggml_vec_dot_f32`, 4 x 4-lane FMA accumulators over blocks of 16, `GGML_F32x4_REDUCE`, `vaddvq_f32`, tail as clang compiles it | exact on 10 shapes (all Kimodo matmuls) | MLX `matmul` (3084469 of 3244032 differ on qkv); sequential sum without FMA |
| `add`, `mul` | `add`, `multiply` | MLX built-ins (one rounding each) | exact | arithmetic in float16 |
| `scale` | `multiply` by a broadcast constant | MLX built-in | exact | float16 |
| `repeat` | `broadcast_in_dim` | MLX built-in | exact | broadcast of the first element |
| `concat` (3 axes) | `concatenate` | MLX built-in | exact | operands swapped |
| `transpose` | `transpose` | MLX built-in | exact | no permutation |
| `view` | `slice` | MLX built-in | exact | offset one element late |
| `norm` | `custom_call`/`composite` `ggml.norm` | kernel `norm`: `double` sums in software binary64, correctly rounded `/` and `sqrt` | exact | binary32 sums with the GPU's `/` and `sqrt` |
| `soft_max` (no mask) | `ggml.soft_max` | kernel `soft_max`: `ggml_v_expf`, `vaddvq_f32` groups summed in binary64, `1.0/sum` in binary64 | exact for rows of 4k | binary32 denominator |
| `unary` SILU | `ggml.silu` | kernel `silu`: `x / (1 + ggml_v_expf(-x))`, exact `/` | exact for rows of 4k | the GPU's `exp` and `/` |
| `unary` GELU_ERF | `ggml.gelu_erf` | kernel `gelu_erf` with a port of the platform `erff` | exact | tanh-form GELU |
| (any) | `divide` (f32) | kernel `divide`, correctly rounded | 0 of 2^20 differ from IEEE | MLX `/` (38876 of 2^20 differ) |
| (any) | `sqrt` (f32) | kernel `sqrt`, correctly rounded | 0 of 2^20 differ | input one ulp off |
| — | `erff` port | kernel `erff_map` | 0 of 2^32 inputs differ from libsystem_m `erff` (9.9 s) | reference shifted by one input |

The kernel pins have their own planted fault: `scripts/pin_fault.sh` checks
that a wrong pin (the `mul_mat` kernel against the `soft_max` Slang) does not
elaborate.

## Gaps, with their causes

* Row tails of `soft_max` and `silu`. ggml-cpu sends a row's last `n mod 4`
  elements through the platform `expf` (libsystem_m), which is not ported. The
  lowering refuses such a row (`soft_max_tail`, `silu_tail` check the refusal).
  Kimodo's rows are multiples of 4.
* `norm` with Accelerate. In the macOS default build (`GGML_ACCELERATE=ON`)
  `ggml_norm` takes its sum and variance from `vDSP_sve` and `vDSP_measqv`,
  whose accumulation order is not published: against that build `norm_kimodo`
  differs in 216283 of 1081344 words (first at word 4: 0x3D7B3551 against
  0x3D7B354F). Every other op gives the same bits in both builds. The
  reference is therefore built with Accelerate off.
* MLX's own `matmul` and `/` are not exact (see the planted faults); MLX's
  `sqrt` matched IEEE on every sampled input but is not relied on.

## Metal compilation

The Metal source is compiled with `#pragma METAL fp contract(off)`, so the GPU
compiler does not fuse a multiply and an add that ggml-cpu rounds separately;
explicit `fma` stays fused. Kernel inputs under 8 elements are padded, because
`metal_kernel` binds them in the `constant` address space.

## Timings

M2 Pro, first call of a compiled module (trace, compile and run): `mul_mat_qkv`
(3244032 outputs) 58 ms, `mul_mat_ffn2` 34 ms, `norm_kimodo` 13 ms,
`gelu_erf_kimodo` 2.9 ms, `soft_max_kimodo` 0.8 ms. The whole suite, with the
2^32-input `erff` check, takes 13 s.
