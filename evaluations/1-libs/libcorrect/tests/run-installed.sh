#!/usr/bin/env bash
set -euo pipefail
: "${LORELEI_DEVKIT:?}" "${QEMU:?}" "${WORK:?}" "${NATIVE_PREFIX:?}" "${GUEST_PREFIX:?}" "${BENCH:?}"
cmake -E remove_directory "$WORK"
mkdir -p "$WORK/results" "$WORK/dump-correct" "$WORK/dump-fec"
tests=(convolutional_test_runner convolutional_shim_test_runner reed_solomon_test_runner reed_solomon_shim_interop_test_runner)
: > "$WORK/guest-undefined.txt"
for test in "${tests[@]}"; do
  binary=$GUEST_PREFIX/tools/libcorrect/upstream-tests/$test
  [[ -x $binary ]] || { echo "Installed upstream test missing: $binary" >&2; exit 2; }
  llvm-nm-20 -D --undefined-only --just-symbol-name "$binary" | sed 's/@.*//' >> "$WORK/guest-undefined.txt"
done
sort -u -o "$WORK/guest-undefined.txt" "$WORK/guest-undefined.txt"
make_thunk() {
  local name=$1 lib_glob=$2 desc=$3 soname=$4 dump=$5
  local host_lib
  host_lib=$(find "$NATIVE_PREFIX/lib" -maxdepth 1 -type f -name "$lib_glob" | head -1)
  llvm-nm-20 -D --defined-only --format=posix "$host_lib" | awk '$2 == "T" || $2 == "W" {n=$1; sub(/@.*/, "", n); print n}' | sort -u > "$dump/host-functions.txt"
  comm -12 "$WORK/guest-undefined.txt" "$dump/host-functions.txt" > "$dump/functions.txt"
  sed '1i[Function]' "$dump/functions.txt" > "$dump/Symbols.conf"
  "$LORELEI_DEVKIT/bin/LoreMakeThunk.py" --name "$name" -o "$WORK/thunk-$name" --lib "$host_lib" \
    --soname "$soname" --symbols "$dump/Symbols.conf" --desc "$desc" --devkit "$LORELEI_DEVKIT" \
    --keep-intermediates -- -I"$NATIVE_PREFIX/include" > "$WORK/results/thunk-$name.log" 2>&1
}
make_thunk correct 'libcorrect.so*' "$BENCH/DescCorrect.h" libcorrect.so "$WORK/dump-correct"
make_thunk fec 'libfec.so*' "$BENCH/DescFEC.h" libfec.so "$WORK/dump-fec"
normalize() { sed -E 's/observed error rate=[^ ]+/observed error rate=RANDOM/' "$1"; }
run_probabilistic_test() {
  local lane=$1 test=$2 attempt output
  shift 2
  output=$WORK/results/$lane-$test.log
  for attempt in 1 2 3 4 5; do
    if "$@" > "$output.attempt-$attempt" 2>&1; then
      cp "$output.attempt-$attempt" "$output"
      return 0
    fi
  done
  cp "$output.attempt-5" "$output"
  echo "$lane $test failed after 5 attempts" >&2
  return 1
}
for test in "${tests[@]}"; do
  run_probabilistic_test native "$test" env LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" \
    "$NATIVE_PREFIX/tools/libcorrect/upstream-tests/$test"
  run_probabilistic_test hecate "$test" env LD_LIBRARY_PATH="$LORELEI_DEVKIT/lib:$NATIVE_PREFIX/lib:$WORK/thunk-correct:$WORK/thunk-fec" \
    "$QEMU" -L "$LORELEI_DEVKIT/x86_64/sysroot" -E LD_BIND_NOW=1 \
    -E "LD_LIBRARY_PATH=$LORELEI_DEVKIT/x86_64/lib:$WORK/thunk-correct/x86_64:$WORK/thunk-fec/x86_64" \
    "$GUEST_PREFIX/tools/libcorrect/upstream-tests/$test"
  normalize "$WORK/results/native-$test.log" > "$WORK/results/native-$test.normalized"
  normalize "$WORK/results/hecate-$test.log" > "$WORK/results/hecate-$test.normalized"
  cmp "$WORK/results/native-$test.normalized" "$WORK/results/hecate-$test.normalized"
done
cp "$WORK/thunk-correct/.gen/correct/ThunkStat.json" "$WORK/dump-correct/ThunkStat.json"
cp "$WORK/thunk-fec/.gen/fec/ThunkStat.json" "$WORK/dump-fec/ThunkStat.json"
printf '{"status":"pass","upstream_registered_tests":4}\n' > "$WORK/results/summary.json"
cat "$WORK/results/summary.json"
