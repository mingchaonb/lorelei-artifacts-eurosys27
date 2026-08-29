#!/usr/bin/env bash

set -euo pipefail
: "${QEMU:?QEMU is required}"
: "${DEVKIT:?DEVKIT is required}"

program=$1
shift
libtool_program=$(dirname "$program")/.libs/$(basename "$program")
if [[ -x "$libtool_program" ]]; then
    program=$libtool_program
fi

: "${HOST_LIB_DIR:?HOST_LIB_DIR is required for Hecate}"
: "${THUNK_DIR:?THUNK_DIR is required for Hecate}"
: "${ERRNO_SHIM_DIR:?ERRNO_SHIM_DIR is required for Hecate}"
exec env LD_LIBRARY_PATH="$DEVKIT/lib:$HOST_LIB_DIR:$THUNK_DIR:$ERRNO_SHIM_DIR" \
    "$QEMU" -L "$DEVKIT/x86_64/sysroot" \
    -E LD_BIND_NOW=1 \
    -E "LD_PRELOAD=$ERRNO_SHIM_DIR/x86_64/errno-shim.so" \
    -E "LD_LIBRARY_PATH=$DEVKIT/x86_64/lib:$THUNK_DIR/x86_64" "$program" "$@"
