#!/usr/bin/env bash
set -euo pipefail

source_dir=$1
build_dir=$2
manifest=$3
launcher=$4
native_root=$5
hecate_root=$6
log_root=$7

cmake -S "$source_dir" -B "$build_dir" \
  -DTEST_MANIFEST="$manifest" \
  -DTEST_LAUNCHER="$launcher" \
  -DTEST_CASE_DRIVER="${TEST_CASE_DRIVER:-}" \
  -DTEST_native_ROOT="$native_root" \
  -DTEST_hecate_ROOT="$hecate_root" \
  -DTEST_native_DATA="${TEST_NATIVE_DATA:-}" \
  -DTEST_hecate_DATA="${TEST_HECATE_DATA:-}" \
  >"$log_root/preparation/ctest-configure.log" 2>&1
ctest --test-dir "$build_dir" -N >"$log_root/preparation/ctest-discovery.log" 2>&1
ctest --test-dir "$build_dir" --output-on-failure -R '^native\.' >"$log_root/native/ctest.log" 2>&1
ctest --test-dir "$build_dir" --output-on-failure -R '^hecate\.' >"$log_root/hecate/ctest.log" 2>&1
