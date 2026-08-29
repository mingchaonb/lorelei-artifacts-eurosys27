#!/usr/bin/env bash
set -euo pipefail

mode=$1
launcher=$2
program=$3
data_root=$4
output_root=$5
kind=$6
input_name=$7
quality=${8:-}

mkdir -p "$output_root"
if [[ $kind == roundtrip ]]; then
  compressed=$output_root/${input_name//\//_}.q$quality.br
  restored=$output_root/${input_name//\//_}.q$quality.out
  "$launcher" "$mode" "$program" -f -q "$quality" -o "$compressed" "$data_root/roundtrip/$input_name"
  "$launcher" "$mode" "$program" -f -d -o "$restored" "$compressed"
  cmp "$data_root/roundtrip/$input_name" "$restored"
else
  restored=$output_root/$input_name.out
  "$launcher" "$mode" "$program" -f -d -o "$restored" "$data_root/compatibility/$input_name.compressed"
  cmp "$data_root/compatibility/$input_name" "$restored"
fi
