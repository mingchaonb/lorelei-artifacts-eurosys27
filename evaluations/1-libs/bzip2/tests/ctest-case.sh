#!/usr/bin/env bash
set -euo pipefail

mode=$1
launcher=$2
program=$3
data_dir=$4
suite_dir=$5

cmake -E remove_directory "$suite_dir"
mkdir -p "$suite_dir"
cp "$data_dir"/sample*.ref "$data_dir"/sample*.bz2 "$suite_dir/"
cd "$suite_dir"
"$launcher" "$mode" "$program" -1 <sample1.ref >sample1.rb2
"$launcher" "$mode" "$program" -2 <sample2.ref >sample2.rb2
"$launcher" "$mode" "$program" -3 <sample3.ref >sample3.rb2
"$launcher" "$mode" "$program" -d <sample1.bz2 >sample1.tst
"$launcher" "$mode" "$program" -d <sample2.bz2 >sample2.tst
"$launcher" "$mode" "$program" -ds <sample3.bz2 >sample3.tst
cmp sample1.bz2 sample1.rb2
cmp sample2.bz2 sample2.rb2
cmp sample3.bz2 sample3.rb2
cmp sample1.ref sample1.tst
cmp sample2.ref sample2.tst
cmp sample3.ref sample3.tst
