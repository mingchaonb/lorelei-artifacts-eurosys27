#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../.common/run-tlc-only.sh" libstemmer stemmer libstemmer.so.0 "$@"
