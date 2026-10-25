#!/usr/bin/env bash
# Build mlx-c and MLX (C++ API, Metal backend) at pinned commits into
# .lake/mlx/prefix, the static archives the lakefile links. No Python.
#
#   scripts/build_mlx.sh
set -euo pipefail

# mlx-c v0.7.0 and the MLX release it builds against (its CMakeLists.txt
# FetchContent tag v0.32.2), both pinned by commit.
MLX_C_SHA=a341b4925024b88b2c593468f16e12f5e17315da
MLX_SHA=1f8e74e3f12f31365464a6867c6579f0e9b29d85

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/.lake/mlx"
mkdir -p "$WORK"
fetch() { # repo sha dir
	if [ ! -d "$3/.git" ]; then git clone -q "$1" "$3"; fi
	git -C "$3" fetch -q origin "$2" 2>/dev/null || true
	git -C "$3" checkout -q "$2"
	test "$(git -C "$3" rev-parse HEAD)" = "$2"
}
fetch https://github.com/ml-explore/mlx-c.git "$MLX_C_SHA" "$WORK/mlx-c"
fetch https://github.com/ml-explore/mlx.git "$MLX_SHA" "$WORK/mlx"

# -include iterator / exception: MLX 0.32.2's jaccl/rdma.h and pocketfft.h use
# std::inserter and std::exception_ptr without including their headers, which
# newer libc++ no longer pulls in transitively.
cmake -S "$WORK/mlx-c" -B "$WORK/build" -G Ninja -DCMAKE_BUILD_TYPE=Release \
	-DMLX_C_BUILD_EXAMPLES=OFF -DFETCHCONTENT_SOURCE_DIR_MLX="$WORK/mlx" \
	-DMLX_BUILD_TESTS=OFF -DMLX_BUILD_EXAMPLES=OFF -DMLX_BUILD_GGUF=OFF -DMLX_BUILD_SAFETENSORS=OFF \
	-DCMAKE_CXX_FLAGS="-include iterator -include exception" \
	-DCMAKE_INSTALL_PREFIX="$WORK/prefix"
cmake --build "$WORK/build"
cmake --install "$WORK/build"
echo "mlx-c $MLX_C_SHA, mlx $MLX_SHA -> $WORK/prefix"
