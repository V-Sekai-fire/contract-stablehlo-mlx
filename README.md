# contract-stablehlo-mlx

A Lean 4 executor that runs StableHLO on Apple's Metal GPU through MLX, bit for bit equal to ggml-cpu, op by op.

## What it is for

It runs the StableHLO that `contract-ggml-stablehlo` emits for a ggml model,
Kimodo's motion denoiser first, on the GPU of an Apple-silicon Mac. The parser,
the op lowering table and the test driver are Lean 4. MLX is reached through its
C API, mlx-c, by `@[extern]` declarations and one small C shim
(`c/smlx_shim.c`). Python is not used.

Where an MLX built-in does not give ggml-cpu's bits, the op runs a custom Metal
kernel. Each kernel is written in Lean, emitted through LeanSlang to Slang,
compiled by `slangc` to Metal, and dispatched by `mx::fast::metal_kernel`. The
committed Metal is pinned to its Lean kernel by `native_decide`
(`StablehloMlx/Kernels/Pins.lean`). The kernels follow ggml-cpu's arm64 NEON
accumulation order, ggml's own `ggml_v_expf`, and the platform `erff`.

The bar is bit equality, never a tolerance. An op that ggml-cpu computes with
code this executor does not carry is refused with the reason. See
[docs/ops.md](docs/ops.md) for each op, its path and its status.

## Build and run

```sh
scripts/build_mlx.sh          # mlx-c v0.7.0 and MLX v0.32.2, pinned by commit
lake build
ref/build.sh ref-out          # pinned ggml-cpu, one reference per op case
.lake/build/bin/op_tests ref-out
scripts/pin_fault.sh
```

`op_tests` runs every case on the GPU twice (traced under `mx::compile`, and
uncompiled), compares every output bit with ggml-cpu, then runs the case's
planted wrong lowering, which must give different bits. It also checks the GPU
`erff` port against the CPU routine on all 2^32 binary32 inputs. To run a
module:

```sh
.lake/build/bin/shlo_mlx module.mlir out/ arg0.bin arg1.bin --repeat 10
```

`lake exe emit_kernels` re-emits the Metal from the Lean kernels (it needs
`slangc` and the Metal toolchain).

## Licence

MIT. See [LICENSE](LICENSE).
