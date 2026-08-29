#!/usr/bin/env bash

set -euo pipefail

: "${IDN2_GUEST:?IDN2_GUEST is required}"
exec "$(dirname "$0")/qemu-wrapper.sh" "$IDN2_GUEST" "$@"
