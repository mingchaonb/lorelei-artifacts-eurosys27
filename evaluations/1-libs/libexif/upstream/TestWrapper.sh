#!/usr/bin/env bash

set -euo pipefail
: "${QEMU_WRAPPER:?QEMU_WRAPPER is required}"
name=$(basename "$0")
exec "$QEMU_WRAPPER" "$(dirname "$0")/.libs/$name" "$@"
