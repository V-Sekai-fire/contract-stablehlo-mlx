#!/usr/bin/env bash
# The planted fault for the kernel pins: a wrong pin must not elaborate, and
# the right pins must, through the same command.
#
#   scripts/pin_fault.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! lake env lean StablehloMlx/Kernels/Pins.lean >/dev/null 2>&1; then
	echo "FAIL pins: the committed pins do not elaborate"
	exit 1
fi
echo "PASS pins: every committed Metal kernel matches its Lean kernel"

out="$(lake env lean Tests/PinFault.lean 2>&1)"
if [ $? -eq 0 ]; then
	echo "FAIL pin planted fault: a wrong pin elaborated"
	exit 1
fi
if ! grep -q "native_decide" <<<"$out"; then
	echo "FAIL pin planted fault: rejected, but not by native_decide:"
	echo "$out"
	exit 1
fi
echo "PASS pin planted fault (mul_mat against the soft_max Slang): rejected by native_decide"
