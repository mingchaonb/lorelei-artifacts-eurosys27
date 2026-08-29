#!/usr/bin/env bash
set -euo pipefail
: "${QEMU_WRAPPER:?QEMU_WRAPPER is required}"
: "${GUEST_DATAGEN:?GUEST_DATAGEN is required}"
exec "$QEMU_WRAPPER" "$GUEST_DATAGEN" "$@"
