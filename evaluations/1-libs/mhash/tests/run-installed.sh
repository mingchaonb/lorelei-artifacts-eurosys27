#!/usr/bin/env bash
set -euo pipefail
: "${DEVKIT:?}" "${QEMU:?}" "${WORK:?}" "${NATIVE_PREFIX:?}" "${GUEST_PREFIX:?}" "${BENCH:?}"
cmake -E remove_directory "$WORK"
mkdir -p "$WORK/results" "$WORK/dump"
tests=(driver hmac_test keygen_test rest_test frag_test)
host_lib=$(find "$NATIVE_PREFIX/lib" -maxdepth 1 -type f -name 'libmhash.so.*' | head -1)
: > "$WORK/dump/guest-undefined.txt"
for name in "${tests[@]}"; do
  llvm-nm-20 -D --undefined-only --just-symbol-name "$GUEST_PREFIX/tools/mhash/upstream-tests/$name" | sed 's/@.*//' >> "$WORK/dump/guest-undefined.txt"
done
sort -u -o "$WORK/dump/guest-undefined.txt" "$WORK/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --just-symbol-name "$host_lib" | sed 's/@.*//' | sort -u > "$WORK/dump/host-functions.txt"
comm -12 "$WORK/dump/guest-undefined.txt" "$WORK/dump/host-functions.txt" > "$WORK/dump/functions.txt"
sed '1i[Function]' "$WORK/dump/functions.txt" > "$WORK/dump/Symbols.conf"
"$DEVKIT/bin/LoreMakeThunk.py" --name mhash -o "$WORK/thunk" --lib "$host_lib" \
  --symbols "$WORK/dump/Symbols.conf" --desc "$BENCH/Desc.h" \
  --manifest-host "$BENCH/Manifest_host.cpp" --devkit "$DEVKIT" --keep-intermediates \
  -- -DPROTOTYPES -I"$NATIVE_PREFIX/include" -I"$NATIVE_PREFIX/include/mutils" \
  > "$WORK/results/thunk.log" 2>&1
run_native() {
  mkdir -p "$WORK/native-hash"
  cp "$NATIVE_PREFIX/tools/mhash/upstream-tests/hash_test.sh" "$WORK/native-hash/"
  ln -sf "$NATIVE_PREFIX/tools/mhash/upstream-tests/driver" "$WORK/native-hash/driver"
  (cd "$WORK/native-hash" && LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" sh ./hash_test.sh)
  for name in hmac_test keygen_test rest_test frag_test; do
    LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" "$NATIVE_PREFIX/tools/mhash/upstream-tests/$name"
  done
}
run_hecate() {
  mkdir -p "$WORK/hecate-hash"
  cp "$GUEST_PREFIX/tools/mhash/upstream-tests/hash_test.sh" "$WORK/hecate-hash/"
  cp "$BENCH/DriverWrapper.sh" "$WORK/hecate-hash/driver"
  chmod +x "$WORK/hecate-hash/driver"
  (cd "$WORK/hecate-hash" && env QEMU="$QEMU" DEVKIT="$DEVKIT" LORE_AE_HECATE=1 \
    HOST_LIB_DIR="$NATIVE_PREFIX/lib" THUNK_DIR="$WORK/thunk" \
    DRIVER_BIN="$GUEST_PREFIX/tools/mhash/upstream-tests/driver" \
    QEMU_WRAPPER="$BENCH/QEMUWrapper.sh" sh ./hash_test.sh)
  for name in hmac_test keygen_test rest_test frag_test; do
    env QEMU="$QEMU" DEVKIT="$DEVKIT" LORE_AE_HECATE=1 HOST_LIB_DIR="$NATIVE_PREFIX/lib" \
      THUNK_DIR="$WORK/thunk" "$BENCH/QEMUWrapper.sh" "$GUEST_PREFIX/tools/mhash/upstream-tests/$name"
  done
}
run_native > "$WORK/results/native.log" 2>&1
run_hecate > "$WORK/results/hecate.log" 2>&1
cmp "$WORK/results/native.log" "$WORK/results/hecate.log"
cp "$WORK/thunk/.gen/mhash/ThunkStat.json" "$WORK/dump/ThunkStat.json"
printf '{"status":"pass","upstream_tests":5}\n' > "$WORK/results/summary.json"
cat "$WORK/results/summary.json"
