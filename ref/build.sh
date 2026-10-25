#!/usr/bin/env bash
# Build ggml-cpu at a pinned commit and the per-op reference generator, then
# write every case:
#
#   ref/build.sh <outdir> [stock|pinned]
#
# Each case directory gets in<i>.f32, out.f32, meta.txt and graph.txt (the graph
# as contract-ggml-stablehlo's backend describes it to its emitter).
#
# stock (the default): ggml-cpu as this Mac builds it (GGML_NATIVE, clang's
# default -ffp-contract=on, the platform libm), with GGML_ACCELERATE=OFF: with
# it on (the macOS default) ggml_norm takes its sum and variance from vDSP_sve
# and vDSP_measqv, whose accumulation order is not published; see docs/ops.md.
# The ggml.* kernels of this executor are checked against this build.
#
# pinned: contract-ggml-stablehlo's reference build (its docs/reference.md):
# GGML_NATIVE=OFF with GGML_CPU_ARM_ARCH=armv8.2-a, -ffp-contract=off, no
# llamafile, KleidiAI or OpenMP, and CORE-MATH's correctly rounded erff and
# expf linked in place of the platform libm. The StableHLO that
# contract-ggml-stablehlo emits is checked against this build.
set -euo pipefail
OUT="${1:?usage: ref/build.sh <outdir> [stock|pinned]}"
FLAVOR="${2:-stock}"
GGML_SHA=29cae86726d8ae2b4d699d8e432fd1bb1801e959   # V-Sekai-fire/ggml, smoke-water 2-contract/ggml
GHLO_SHA=0ad3c7780fab8c038cf2da1947ef07192a31851f   # V-Sekai-fire/contract-ggml-stablehlo
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/.lake/ggml"
mkdir -p "$WORK"
fetch() { # repo sha dir
	if [ ! -d "$3/.git" ]; then git clone -q "$1" "$3"; fi
	git -C "$3" fetch -q origin "$2" 2>/dev/null || true
	git -C "$3" checkout -q "$2"
	test "$(git -C "$3" rev-parse HEAD)" = "$2"
}
fetch https://github.com/V-Sekai-fire/ggml.git "$GGML_SHA" "$WORK/ggml"
BASE=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DGGML_ACCELERATE=OFF -DGGML_METAL=OFF -DGGML_BLAS=OFF
	-DBUILD_SHARED_LIBS=OFF -DGGML_BUILD_TESTS=OFF -DGGML_BUILD_EXAMPLES=OFF)
case "$FLAVOR" in
stock)
	B="$WORK/build"
	cmake -S "$WORK/ggml" -B "$B" "${BASE[@]}"
	EXTRA=()
	CFLAGS=(-O2)
	;;
pinned)
	B="$WORK/build-pinned"
	fetch https://github.com/V-Sekai-fire/contract-ggml-stablehlo.git "$GHLO_SHA" "$WORK/ghlo"
	cmake -S "$WORK/ggml" -B "$B" "${BASE[@]}" -DGGML_LLAMAFILE=OFF -DGGML_CPU_KLEIDIAI=OFF -DGGML_OPENMP=OFF \
		-DGGML_NATIVE=OFF -DGGML_CPU_ARM_ARCH=armv8.2-a \
		-DCMAKE_C_FLAGS=-ffp-contract=off "-DCMAKE_CXX_FLAGS=-ffp-contract=off -include cerrno"
	G="$WORK/ghlo"
	EXTRA=("$G/c/pinned_libm.c" "$G/third_party/core-math/erff.c" "$G/third_party/core-math/expf.c")
	CFLAGS=(-O2 -ffp-contract=off)
	;;
*) echo "unknown flavor $FLAVOR (stock or pinned)" >&2; exit 2 ;;
esac
cmake --build "$B"
cc "${CFLAGS[@]}" -I"$WORK/ggml/include" "$ROOT/ref/ggml_ref.c" ${EXTRA[@]+"${EXTRA[@]}"} \
	"$B/src/libggml.a" "$B/src/libggml-cpu.a" "$B/src/libggml-base.a" -lc++ -o "$WORK/ggml_ref_$FLAVOR"
"$WORK/ggml_ref_$FLAVOR" "$OUT"
