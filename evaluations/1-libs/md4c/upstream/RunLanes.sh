#!/usr/bin/env bash
set -euo pipefail

bench=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$bench/../../../.." && pwd)
work=${WORK:-$root/build/ae-md4c}

for lane in hecate; do
  hecate=0
  [[ "$lane" == hecate ]] && hecate=1
  LORE_AE_HECATE=$hecate "$bench/RunSuite.sh" "$work/source" \
    "$bench/LaneRunner.sh" "$work/results/${lane}-test.log"
done
