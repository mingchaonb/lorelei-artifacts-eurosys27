#!/usr/bin/env bash

set -euo pipefail

tool=$(basename "$0")
directory=$(cd "$(dirname "$0")" && pwd)
if [[ -n ${NATIVE_TOOL_DIR:-} ]]; then
    exec "$NATIVE_TOOL_DIR/.libs/$tool" "$@"
fi
: "${QEMU_WRAPPER:?QEMU_WRAPPER is required}"
exec "$QEMU_WRAPPER" "$directory/.libs/$tool" "$@"
