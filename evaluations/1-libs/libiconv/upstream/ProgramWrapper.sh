#!/usr/bin/env bash

set -euo pipefail
: "${QEMU_WRAPPER:?QEMU_WRAPPER is required}"
directory=$(dirname "$0")
name=$(basename "$0")
real="$directory/.libs/$name"
if [[ ! -x "$real" ]]; then
    real="$directory/$name.guest"
fi
exec "$QEMU_WRAPPER" "$real" "$@"
