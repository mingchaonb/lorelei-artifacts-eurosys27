#!/usr/bin/env bash
set -euo pipefail
: "${QEMU_WRAPPER:?QEMU_WRAPPER is required}"
exec "$QEMU_WRAPPER" "$0.guest" "$@"
