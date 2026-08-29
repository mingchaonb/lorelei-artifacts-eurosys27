#!/usr/bin/env bash

set -euo pipefail

: "${DRIVER_BIN:?DRIVER_BIN is required}"
exec "${QEMU_WRAPPER:?QEMU_WRAPPER is required}" "$DRIVER_BIN" "$@"
