#!/usr/bin/env bash
# Build ggml-cpu at a pinned commit and the per-op reference generator, then
# write every case:
#
#   ref/build.sh <outdir>
#
# GGML_ACCELERATE=OFF: with it on (the macOS default) ggml_norm takes its sum
# and variance from vDSP_sve and vDSP_measqv, whose accumulation order is not
# published; see docs/ops.md. Every other op is the same in both builds.
set -euo pipefail
OUT="${1:?usage: ref/build.sh <outdir>}"
GGML_SHA=29cae86726d8ae2b4d699d8e432fd1bb1801e959   # V-Sekai-fire/ggml, smoke-water 2-contract/ggml
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/.lake/ggml"
mkdir -p "$WORK"
if [ ! -d "$WORK/ggml/.git" ]; then git clone -q https://github.com/V-Sekai-fire/ggml.git "$WORK/ggml"; fi
git -C "$WORK/ggml" fetch -q origin "$GGML_SHA" 2>/dev/null || true
git -C "$WORK/ggml" checkout -q "$GGML_SHA"
test "$(git -C "$WORK/ggml" rev-parse HEAD)" = "$GGML_SHA"
cmake -S "$WORK/ggml" -B "$WORK/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DGGML_ACCELERATE=OFF \
	-DGGML_METAL=OFF -DGGML_BLAS=OFF -DBUILD_SHARED_LIBS=OFF -DGGML_BUILD_TESTS=OFF -DGGML_BUILD_EXAMPLES=OFF
cmake --build "$WORK/build"
B="$WORK/build/src"
cc -O2 -I"$WORK/ggml/include" "$ROOT/ref/ggml_ref.c" "$B/libggml.a" "$B/libggml-cpu.a" "$B/libggml-base.a" \
	-lc++ -o "$WORK/ggml_ref"
"$WORK/ggml_ref" "$OUT"
