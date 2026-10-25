# RESUME — contract-stablehlo-mlx (parked 2026-10-25)

## State

* `main` (78062f6): the Lean executor, the `ggml.*` custom-call/composite path,
  per-op tests with planted faults, CI (`.github/workflows/gpu.yml`, macos-15
  arm64). The first CI run was still building MLX when parked; its result is not known.
* `dev/ghlo-generic-path` (this branch): the generic path that runs the StableHLO
  `contract-ggml-stablehlo` emits, plus `evidence/` (probes, reference hashes,
  findings). No PR is open for it yet.
* Manifest PR: chibifire-smoke-water/contract-manifest-smoke-water#64 (not merged).

## Bit-exact per op (Apple M2 Pro GPU)

`ggml.*` path, against `ref/build.sh <dir> stock` (116 of 116 checks pass,
`op_tests ../refStock`, 13 s):

| op | path | status |
|---|---|---|
| mul_mat (dot_general) | custom kernel `mul_mat` (ggml_vec_dot_f32 NEON order) | exact, 10 shapes |
| add, mul, scale, repeat, concat x3, transpose, view | MLX built-ins | exact |
| norm | custom kernel `norm` (soft binary64 sums) | exact |
| soft_max | custom kernel `soft_max` | exact for rows of 4k; tails refused (platform expf not ported) |
| silu | custom kernel `silu` | exact for rows of 4k; tails refused (same cause) |
| gelu_erf | custom kernel with the platform erff port | exact; erff port 0 of 2^32 differ |
| divide / sqrt (f32) | custom kernels | exact; MLX `/` differs on 38876 of 2^20 |

Not exact, with cause: MLX `matmul` (own accumulation order), MLX `/` (not
correctly rounded), MLX exp/erf/tanh (other functions), `norm` against an
Accelerate build (vDSP order unpublished: 216283 of 1081344 words differ).

Generic path (contract-ggml-stablehlo's modules, f64 as soft float on uint64,
while unrolled at trace time, dynamic_slice, gather, max reduce), against
`ref/build.sh <dir> pinned`: all 38 cases bit-exact when run one by one with
`shlo_mlx` (timings in `evidence/README.md`; mul_mat_qkv 6.5 s, others < 4 s),
including soft_max/silu tails and CORE-MATH erff.

## What failed or is unfinished

* `op_tests ../refStock --pinned ../refPinned` (the integrated generic-path
  checks in `Tests/OpTests.lean`, `ghloCase`) was edited last and is NOT
  verified: the last full run did not finish in 420 s (it stalled in the
  composite cases; the cause is not known, possibly a concurrent GPU job). A
  first version failed only because inputs were built rank 3 while the modules
  take rank 4; that is fixed (inputs take the module's argument types) but not re-run.
* CI does not yet build the pinned reference, run `scripts/GhloEmit.lean`, or pass `--pinned`.
* README, docs/ops.md and CITATION.cff do not yet describe the generic path
  (evidence/README.md does).
* Kimodo end-to-end (one denoiser step, 50-step clip, seed 1171) is not run: it
  waits on contract-ggml-stablehlo PR #1 (dev/lean-backend, 0ad3c77) emitting
  Kimodo's root_model/body_model graphs as modules. Note: the stillcrawl
  reference `transforms.f32` came from the RISC-V guest's ggml-cpu, whose
  accumulation order differs from both arm64 references here.

## Next commands

```sh
cd contract-stablehlo-mlx
scripts/build_mlx.sh && lake build
ref/build.sh ../refStock stock && ref/build.sh ../refPinned pinned
(cd .lake/ggml/ghlo && lake build GgmlStablehlo && lake env lean --run ../../../scripts/GhloEmit.lean "$(cd ../../../../refPinned && pwd)")
.lake/build/bin/op_tests ../refStock --pinned ../refPinned add_small norm_small mul_mat_k2   # check ghloCase first
.lake/build/bin/op_tests ../refStock --pinned ../refPinned                                    # then everything
scripts/pin_fault.sh
```

Then: add the pinned/GhloEmit/--pinned steps to CI, update README and
docs/ops.md, open the PR for this branch (merge commits only, do not merge).
