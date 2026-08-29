#!/usr/bin/env bash
set -euo pipefail

mode=$1
launcher=$2
program=$3
work_dir=$4

cmake -E remove_directory "$work_dir"
mkdir -p "$work_dir"
printf '%s\n' 'zlib minigzip shared-library test' >"$work_dir/input"
"$launcher" "$mode" "$program" <"$work_dir/input" >"$work_dir/output.gz"
"$launcher" "$mode" "$program" -d <"$work_dir/output.gz" >"$work_dir/restored"
cmp "$work_dir/input" "$work_dir/restored"
