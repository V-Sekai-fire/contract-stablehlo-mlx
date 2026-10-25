# Evidence

What was measured on the desk (macOS 26.6 arm64, Apple M2 Pro, MLX v0.32.2
through mlx-c v0.7.0), kept so the findings survive the scratch directory.
Large binaries are not committed; their SHA-256 hashes are.

## Files

| File | What it is |
|---|---|
| `ref-stock.sha256` | SHA-256 of every input, output and `graph.txt` that `ref/build.sh <dir> stock` writes |
| `ref-pinned.sha256` | the same for `ref/build.sh <dir> pinned` (contract-ggml-stablehlo's reference build) |
| `probes/dot*.c`, `probes/c.metal` | the `ggml_vec_dot_f32` order probes: which tail form clang compiles, and that `#pragma METAL fp contract(off)` keeps a separate multiply and add as two roundings on the GPU |
| `probes/vec.dis` | the disassembly of `ggml_vec_dot_f32` from the stock `libggml-cpu.a` (the tail is a scalar `fmadd` loop) |
| `probes/e.c`, `probes/erff.dis`, `probes/erff.tab`, `probes/erfftable.lean` | the platform `erff` (libsystem_m): its disassembly and the 256-word coefficient table read from memory with lldb, as ported to `StablehloMlx/Kernels/Math.lean` |
| `probes/vdsp.c`, `probes/s.c` | the search for `vDSP_sve` / `vDSP_measqv`'s accumulation order (no candidate order of 1-16 four-lane accumulators, tree or sequential, fused or not, matched; see below) |
| `probes/t.slang`, `probes/t.metal` | Slang's `precise` qualifier is not valid Metal (`slangc -target metal` emits it as is); contraction is controlled by the pragma instead |

To check a reference build against the hashes:

```sh
ref/build.sh /tmp/ref stock && (cd /tmp/ref && shasum -a 256 -c "$OLDPWD/evidence/ref-stock.sha256")
```

## MLX built-ins: exact or not

| MLX op | Exact against IEEE / ggml-cpu? | Cause | What runs instead |
|---|---|---|---|
| `add`, `subtract`, `multiply`, `maximum`, `minimum`, compares, bit ops, `where` | exact | one correctly rounded operation (or none) per element on the GPU | the built-in |
| reshape, transpose, broadcast, slice, concatenate, take, astype between integers, view | exact | data movement | the built-in |
| `divide` (f32) | no: 38876 of 2^20 random normal pairs differ | the Metal `/` is not correctly rounded | `divide` kernel (binary64 quotient, narrowed; double rounding is innocuous for `/`) |
| `sqrt` (f32) | 0 of 2^20 differed, but not specified to be correctly rounded | Metal's `sqrt` precision is not guaranteed | `sqrt` kernel (integer square root) |
| `matmul` | no: 3084469 of 3244032 differ on Kimodo's qkv | its own blocking and accumulation order | `mul_mat` kernel in `ggml_vec_dot_f32`'s order, or the generic module's own loop |
| `exp`, `erf`, `tanh`, `sigmoid` | no (different functions from ggml's) | GPU approximations | `ggml_v_expf`, the platform `erff` port, or the generic module's CORE-MATH code |
| float64 | not available on the GPU | Metal has no binary64 | soft-float kernels on uint64 bit patterns (`f64_ew`, `f64_of_f32`, `f32_of_f64`) |

## Two references, and why

ggml-cpu's bits depend on how it is built:

* **stock** (this Mac's default build, Accelerate off): `-mcpu=native`, clang's
  default `-ffp-contract=on`, the platform libm. The mul_mat tail is a fused
  `fmadd` loop; `erff` and `expf` are libsystem_m's.
* **pinned** (contract-ggml-stablehlo's `docs/reference.md`): armv8.2-a,
  `-ffp-contract=off`, CORE-MATH `erff` and `expf`. The mul_mat tail is a rounded
  multiply then an add.

The two give different bits on exactly these cases: `mul_mat_small`, `mul_mat_k2`,
`mul_mat_heading`, `mul_mat_root_in`, `mul_mat_body_in` (K not a multiple of
16: the tail) and `gelu_erf_kimodo` (platform `erff` against CORE-MATH; the
small case's inputs happen to agree). Every other case is identical.

The `ggml.*` kernels follow stock. The StableHLO that contract-ggml-stablehlo
emits follows pinned, and is checked against pinned.

## Accelerate's norm

With `GGML_ACCELERATE=ON` (the macOS default), `ggml_norm` takes its sum and
variance from `vDSP_sve` and `vDSP_measqv`. Against that build `norm_kimodo`
differs in 216283 of 1081344 words (first at word 4: 0x3D7B3551 against
0x3D7B354F). `probes/vdsp.c` tried 1, 2, 4, 8 and 16 four-lane accumulators,
pairwise-tree and sequential reductions, fused and unfused squares: none
matched (at best 159 of 300 rows differed). The order is not published, so
both references are built with Accelerate off.

## The generic path: contract-ggml-stablehlo's modules on MLX

`scripts/GhloEmit.lean`, run in contract-ggml-stablehlo at 0ad3c77, turns each
case's `graph.txt` into the module that emitter writes. `shlo_mlx` ran each on
the GPU (compiled) with the pinned reference's inputs. All 38 cases were
bit-exact against the pinned reference, including the row tails that the
`ggml.*` path refuses (`soft_max_tail`, `silu_tail`: CORE-MATH `expf` spelled
out in StableHLO) and `gelu_erf_kimodo` (CORE-MATH `erff`).

First call (trace, compile and run), M2 Pro:

| case | ms | case | ms |
|---|---|---|---|
| mul_mat_qkv (1024 x 3072 x 1056) | 6460 | mul_mat_ffn2 | 3835 |
| mul_mat_root_in | 1488 | mul_mat_body_in | 1433 |
| mul_mat_text | 1306 | norm_kimodo | 567 |
| gelu_erf_kimodo | 153 | soft_max_kimodo | 106 |
| silu_kimodo | 93 | mul_mat_scores | 95 |
| add_kimodo | 21 | norm_small | 1285 (first kernel compiles) |

The generic mul_mat is 100 times slower than the `mul_mat` kernel (58 ms for
qkv): its exact FMA is a dozen soft binary64 operations per step on
`[M, N, 16]` tensors. That is the cost of running the emitter's arithmetic as
written.
