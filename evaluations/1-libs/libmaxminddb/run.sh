#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "${BASH_SOURCE[0]}")/../.common/run-tlc-only.sh" libmaxminddb maxminddb libmaxminddb.so "$@"
