#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/run-tlc-only.sh" libmaxminddb maxminddb libmaxminddb.so "$@"
