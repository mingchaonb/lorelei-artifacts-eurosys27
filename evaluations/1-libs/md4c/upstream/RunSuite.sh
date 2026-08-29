#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
program=$2
output=$3

cd "$source_dir/test"
for spec in spec.txt regressions.txt spec-*.txt; do
  echo "SPEC=$spec"
  python3 run-testsuite.py -p "$program" -s "$spec"
done > "$output"
python3 pathological-tests.py -p "$program" > "${output%.log}-pathological.log"

cat "$output"
tail -1 "${output%.log}-pathological.log"
