#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
base=$(dirname "$root")
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
work=${WORK:-"$root/build/ae-libidn"}
real=$1
shift
guest_argv0=$(basename "$real" .lore-real)

if [[ "${LORE_AE_HECATE:-0}" == 1 ]]; then
  exec env LD_LIBRARY_PATH="$devkit/lib:$work/native/lib/.libs:$work/thunk:$work/thunk-libc-shim" \
    "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 \
    -E "LD_PRELOAD=$work/thunk-libc-shim/x86_64/libc-shim.so" \
    -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64:$work/guest-data" \
    -0 "$guest_argv0" "$real" "$@"
fi

exec env LD_LIBRARY_PATH="$devkit/lib" "$qemu" -L "$devkit/x86_64/sysroot" \
  -E "LD_LIBRARY_PATH=$work/guest/lib/.libs" -0 "$guest_argv0" "$real" "$@"
