#!/usr/bin/env bash
set -euo pipefail
: "${LORELEI_DEVKIT:?}"
: "${QEMU:?}"
: "${SOURCE:?}"
: "${WORK:?}"
: "${BENCH:?}"
devkit=$LORELEI_DEVKIT
qemu=$QEMU
work=$WORK
cmake -E remove_directory "$work"
mkdir -p "$work/source" "$work/native" "$work/guest" "$work/results" "$work/dump-correct" "$work/dump-fec"
cmake -E copy_directory "$SOURCE" "$work/source"
if rg -n '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
  "$work/source/src" "$work/source/include" \
  > "$work/results/production-setjmp.txt"; then
  echo "production non-local jump found" >&2
  exit 2
fi

configure_build() {
  local lane=$1
  shift
  cmake -S "$work/source" -B "$work/$lane" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DHAVE_SSE=OFF -DHAVE_LIBFEC=OFF "$@" \
    > "$work/results/$lane-configure.log" 2>&1
  cmake --build "$work/$lane" \
    --target correct fec_shim_shared test_runners -j8 \
    > "$work/results/$lane-build.log" 2>&1
}
configure_build native -DCMAKE_C_COMPILER=clang-20
guest_cc=$devkit/bin/x86_64-linux-gnu-clang
guest_sysroot=$devkit/x86_64/sysroot
configure_build guest -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=x86_64 -DCMAKE_C_COMPILER="$guest_cc" \
  -DCMAKE_SYSROOT="$guest_sysroot"

ctest --test-dir "$work/native/tests" --output-on-failure \
  > "$work/results/upstream-static-ctest.log" 2>&1
grep -q '100% tests passed, 0 tests failed out of 4' \
  "$work/results/upstream-static-ctest.log"

relink() {
  local lane=$1
  local cc=$2
  local sysroot=$3
  local build=$work/$lane
  local out=$build/tests-dynamic
  mkdir -p "$out"
  local flags=(-O3)
  if [[ -n "$sysroot" ]]; then flags+=(--sysroot="$sysroot"); fi
  "$cc" "${flags[@]}" \
    "$build/util/CMakeFiles/error_sim.dir/error-sim.c.o" \
    "$build/tests/CMakeFiles/convolutional_test_runner.dir/convolutional.c.o" \
    -L"$build/lib" -Wl,-rpath,"$build/lib" -lcorrect -lm \
    -o "$out/convolutional_test_runner"
  "$cc" "${flags[@]}" \
    "$build/util/CMakeFiles/error_sim_shim.dir/error-sim.c.o" \
    "$build/util/CMakeFiles/error_sim_shim.dir/error-sim-shim.c.o" \
    "$build/tests/CMakeFiles/convolutional_shim_test_runner.dir/convolutional-shim.c.o" \
    -L"$build/lib" -Wl,-rpath,"$build/lib" -lcorrect -lfec -lm \
    -o "$out/convolutional_shim_test_runner"
  "$cc" "${flags[@]}" \
    "$build/tests/CMakeFiles/reed_solomon_test_runner.dir/reed-solomon.c.o" \
    "$build/tests/CMakeFiles/reed_solomon_test_runner.dir/rs_tester.c.o" \
    -L"$build/lib" -Wl,-rpath,"$build/lib" -lcorrect -lm \
    -o "$out/reed_solomon_test_runner"
  "$cc" "${flags[@]}" \
    "$build/tests/CMakeFiles/reed_solomon_shim_interop_test_runner.dir/reed-solomon-shim-interop.c.o" \
    "$build/tests/CMakeFiles/reed_solomon_shim_interop_test_runner.dir/rs_tester.c.o" \
    "$build/tests/CMakeFiles/reed_solomon_shim_interop_test_runner.dir/rs_tester_fec_shim.c.o" \
    -L"$build/lib" -Wl,-rpath,"$build/lib" -lcorrect -lfec -lm \
    -o "$out/reed_solomon_shim_interop_test_runner"
}
relink native clang-20 ''
relink guest "$guest_cc" "$guest_sysroot"

tests=(convolutional_test_runner convolutional_shim_test_runner \
  reed_solomon_test_runner reed_solomon_shim_interop_test_runner)
normalize() {
  sed -E 's/observed error rate=[^ ]+/observed error rate=RANDOM/' "$1"
}
for test in "${tests[@]}"; do
  readelf -d "$work/guest/tests-dynamic/$test" \
    > "$work/results/$test-dynamic.txt"
  /usr/bin/time -f 'native_seconds=%e' env \
    LD_LIBRARY_PATH="$work/native/lib" "$work/native/tests-dynamic/$test" \
    > "$work/results/native-$test.log" \
    2> "$work/results/native-$test.time"
  normalize "$work/results/native-$test.log" \
    > "$work/results/native-$test.normalized"
done

for test in "${tests[@]}"; do
  llvm-nm-20 -D --undefined-only --just-symbol-name \
    "$work/guest/tests-dynamic/$test"
done | sed 's/@.*//' | sort -u > "$work/guest-undefined.txt"
for name in correct fec; do
  llvm-nm-20 -D --defined-only --format=posix \
    "$work/native/lib/lib$name.so" \
    | awk '$2 == "T" || $2 == "W" {print $1}' | sort -u \
    > "$work/$name-exports.txt"
done
comm -12 "$work/guest-undefined.txt" "$work/correct-exports.txt" \
  > "$work/dump-correct/functions.txt"
comm -23 "$work/fec-exports.txt" "$work/correct-exports.txt" \
  | comm -12 "$work/guest-undefined.txt" - > "$work/dump-fec/functions.txt"
for name in correct fec; do
  sed '1i[Function]' "$work/dump-$name/functions.txt" \
    > "$work/dump-$name/Symbols.conf"
  readelf -Ws "$work/native/lib/lib$name.so" \
    | awk '($4 == "OBJECT" || $4 == "TLS") && $5 == "GLOBAL" && $7 != "UND" && $7 != "ABS" {print $8}' \
    | sed 's/@.*//' | sort -u > "$work/dump-$name/host-data-tls.txt"
  comm -12 "$work/guest-undefined.txt" "$work/dump-$name/host-data-tls.txt" \
    > "$work/dump-$name/data-used.txt"
done

"$devkit/bin/LoreMakeThunk.py" --name correct -o "$work/thunk-correct" \
  --lib "$work/native/lib/libcorrect.so" \
  --symbols "$work/dump-correct/Symbols.conf" \
  --desc "$BENCH/DescCorrect.h" --devkit "$devkit" \
  --keep-intermediates -- -I"$work/source/include" \
  > "$work/results/thunk-correct.log" 2>&1
"$devkit/bin/LoreMakeThunk.py" --name fec -o "$work/thunk-fec" \
  --lib "$work/native/lib/libfec.so" \
  --symbols "$work/dump-fec/Symbols.conf" --desc "$BENCH/DescFEC.h" \
  --devkit "$devkit" --keep-intermediates -- -I"$work/source/include" \
  > "$work/results/thunk-fec.log" 2>&1

for test in "${tests[@]}"; do
  /usr/bin/time -f 'hecate_seconds=%e' env \
    LD_LIBRARY_PATH="$devkit/lib:$work/native/lib:$work/thunk-correct:$work/thunk-fec" \
    "$qemu" -L "$guest_sysroot" -E LD_BIND_NOW=1 \
    -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk-correct/x86_64:$work/thunk-fec/x86_64:$work/guest/lib" \
    "$work/guest/tests-dynamic/$test" > "$work/results/hecate-$test.log" \
    2> "$work/results/hecate-$test.time"
  normalize "$work/results/hecate-$test.log" \
    > "$work/results/hecate-$test.normalized"
  cmp "$work/results/native-$test.normalized" \
    "$work/results/hecate-$test.normalized"
done
cp "$work/thunk-correct/.gen/correct/ThunkStat.json" \
  "$work/dump-correct/ThunkStat.json"
cp "$work/thunk-fec/.gen/fec/ThunkStat.json" \
  "$work/dump-fec/ThunkStat.json"
correct_functions=$(wc -l < "$work/dump-correct/functions.txt")
fec_functions=$(wc -l < "$work/dump-fec/functions.txt")

cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "version": "pinned upstream snapshot",
  "commit": "ee82e6673a806dfdf0a969b975ab36596ecc5401",
  "upstream_registered_tests": 4,
  "targets": [
    {"soname": "libcorrect.so", "functions": $correct_functions},
    {"soname": "libfec.so", "functions": $fec_functions}
  ],
  "callbacks": 0,
  "guest_data_references": 0,
  "adaptation": "TLC only with C-linkage descriptor"
}
EOF
cat "$work/results/summary.json"
