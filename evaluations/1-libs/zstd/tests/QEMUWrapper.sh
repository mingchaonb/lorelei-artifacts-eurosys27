#!/usr/bin/env bash
set -euo pipefail
: "${QEMU:?QEMU is required}"
: "${DEVKIT:?DEVKIT is required}"
: "${GUEST_LIB_DIR:?GUEST_LIB_DIR is required}"
if [[ ${LORE_AE_HECATE:-0} == 1 ]]; then
  exec env LD_PRELOAD="$DEVKIT/lib/libLoreQEMUThreadHook.so" LD_LIBRARY_PATH="$DEVKIT/lib:$HOST_LIB_DIR:$THUNK_DIR" "$QEMU" -L "$DEVKIT/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$DEVKIT/x86_64/lib:$THUNK_DIR/x86_64" "$@"
fi
exec env LD_LIBRARY_PATH="$DEVKIT/lib" "$QEMU" -L "$DEVKIT/x86_64/sysroot" -E "LD_LIBRARY_PATH=$GUEST_LIB_DIR" "$@"
