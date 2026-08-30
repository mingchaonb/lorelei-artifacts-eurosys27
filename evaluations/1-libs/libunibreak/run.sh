#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "${BASH_SOURCE[0]}")/../_common/run-tlc-only.sh" libunibreak unibreak libunibreak.so.7 "$@"
