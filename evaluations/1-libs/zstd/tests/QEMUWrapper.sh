#!/usr/bin/env bash
set -euo pipefail
: "${QEMU:?QEMU is required}"
: "${LORELEI_DEVKIT:?LORELEI_DEVKIT is required}"
: "${GUEST_LIB_DIR:?GUEST_LIB_DIR is required}"
if [[ ${LORE_AE_HECATE:-0} == 1 ]]; then
  exec env LD_PRELOAD="$LORELEI_DEVKIT/lib/libLoreQEMUThreadHook.so" LD_LIBRARY_PATH="$LORELEI_DEVKIT/lib:$HOST_LIB_DIR:$THUNK_DIR" "$QEMU" -L "$LORELEI_DEVKIT/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$LORELEI_DEVKIT/x86_64/lib:$THUNK_DIR/x86_64" "$@"
fi
exec env LD_LIBRARY_PATH="$LORELEI_DEVKIT/lib" "$QEMU" -L "$LORELEI_DEVKIT/x86_64/sysroot" -E "LD_LIBRARY_PATH=$GUEST_LIB_DIR" "$@"
