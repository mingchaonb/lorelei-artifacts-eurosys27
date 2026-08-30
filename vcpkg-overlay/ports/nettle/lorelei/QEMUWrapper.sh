#!/usr/bin/env bash

set -euo pipefail
: "${QEMU:?QEMU is required}"
: "${LORELEI_DEVKIT:?LORELEI_DEVKIT is required}"

program=$1
shift

if [[ "${LORE_AE_HECATE:-0}" == 1 ]]; then
    : "${HOST_LIB_DIR:?HOST_LIB_DIR is required for Hecate}"
    : "${THUNK_DIR:?THUNK_DIR is required for Hecate}"
    exec env LD_PRELOAD="$LORELEI_DEVKIT/lib/libLoreQEMUThreadHook.so" \
        LD_LIBRARY_PATH="$LORELEI_DEVKIT/lib:$HOST_LIB_DIR:$THUNK_DIR" \
        "$QEMU" -L "$LORELEI_DEVKIT/x86_64/sysroot" \
        -U LD_PRELOAD \
        -E LD_BIND_NOW=1 \
        -E "LD_LIBRARY_PATH=$LORELEI_DEVKIT/x86_64/lib:$THUNK_DIR/x86_64" \
        "$program" "$@"
fi

: "${GUEST_LIB_DIR:?GUEST_LIB_DIR is required for pure QEMU}"
exec env LD_LIBRARY_PATH="$LORELEI_DEVKIT/lib" \
    "$QEMU" -L "$LORELEI_DEVKIT/x86_64/sysroot" \
    -E "LD_LIBRARY_PATH=$GUEST_LIB_DIR" "$program" "$@"
