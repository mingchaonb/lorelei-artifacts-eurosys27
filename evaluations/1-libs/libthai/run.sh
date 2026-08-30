#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "${BASH_SOURCE[0]}")/../_common/run-tlc-only.sh" libthai thai libthai.so.0 "$@"
