#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
base=$(dirname "$root")
devkit=${DEVKIT:-$root/build/install}
qemu=${QEMU:-$base/qemu-ae/build/qemu-x86_64}
work=${WORK:-$root/build/ae-md4c}

if [[ "${LORE_AE_HECATE:-0}" == 1 ]]; then
  exec env LD_LIBRARY_PATH="$devkit/lib:$work/native/src:$work/thunk" \
    "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 \
    -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64:$work/guest/src" \
    "$work/guest/md2html/md2html" "$@"
fi

exec env LD_LIBRARY_PATH="$devkit/lib" "$qemu" \
  -L "$devkit/x86_64/sysroot" \
  -E "LD_LIBRARY_PATH=$work/guest/src" \
  "$work/guest/md2html/md2html" "$@"
