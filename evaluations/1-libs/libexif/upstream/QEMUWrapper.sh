#!/usr/bin/env bash

set -euo pipefail
: "${QEMU:?QEMU is required}"
: "${DEVKIT:?DEVKIT is required}"

if [[ "${LORE_AE_HECATE:-0}" == 1 ]]; then
    : "${LIBC_SHIM_DIR:?LIBC_SHIM_DIR is required for Hecate}"
    exec env LD_LIBRARY_PATH="$DEVKIT/lib:$HOST_LIB_DIR:$THUNK_DIR:$LIBC_SHIM_DIR" \
        "$QEMU" -L "$DEVKIT/x86_64/sysroot" \
        -E LD_BIND_NOW=1 \
        -E "LD_PRELOAD=$LIBC_SHIM_DIR/x86_64/libc-shim.so" \
        -E "LD_LIBRARY_PATH=$DEVKIT/x86_64/lib:$THUNK_DIR/x86_64:$GUEST_LIB_DIR" "$@"
fi

exec env LD_LIBRARY_PATH="$DEVKIT/lib" "$QEMU" -L "$DEVKIT/x86_64/sysroot" \
    -E "LD_LIBRARY_PATH=$GUEST_LIB_DIR" "$@"
