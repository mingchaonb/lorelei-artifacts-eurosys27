#!/usr/bin/env bash
set -euo pipefail
: "${DEVKIT:?}" "${QEMU:?}" "${WORK:?}" "${NATIVE_PREFIX:?}" "${GUEST_PREFIX:?}" "${BENCH:?}" "${QEMU_WRAPPER:?}"
cmake -E remove_directory "$WORK"
mkdir -p "$WORK/results" "$WORK/dump" "$WORK/native-suite" "$WORK/hecate-suite"
native_root=$NATIVE_PREFIX/tools/libsodium/upstream-tests
guest_root=$GUEST_PREFIX/tools/libsodium/upstream-tests
host_lib=$(find "$NATIVE_PREFIX/lib" -maxdepth 1 -type f -name 'libsodium.so.*' | head -1)
find "$guest_root/bin" -maxdepth 1 -type f -perm -111 -exec file {} + | awk -F: '/ELF 64-bit LSB.*x86-64/ {print $1}' | sort > "$WORK/dump/guest-binaries.txt"
while read -r binary; do llvm-nm-20 -D --undefined-only --just-symbol-name "$binary"; done < "$WORK/dump/guest-binaries.txt" | sed 's/@.*//' | sort -u > "$WORK/dump/guest-undefined.txt"
llvm-nm-20 -D --defined-only --format=posix "$host_lib" | awk '$2 == "T" || $2 == "W" {n=$1; sub(/@.*/, "", n); print n}' | sort -u > "$WORK/dump/host-functions.txt"
comm -12 "$WORK/dump/guest-undefined.txt" "$WORK/dump/host-functions.txt" > "$WORK/dump/functions.txt"
sed -i '/^sodium_allocarray$/d; /^sodium_free$/d; /^sodium_malloc$/d; /^sodium_memzero$/d; /^sodium_misuse$/d; /^sodium_mprotect_noaccess$/d; /^sodium_mprotect_readonly$/d; /^sodium_mprotect_readwrite$/d; /^sodium_set_misuse_handler$/d' "$WORK/dump/functions.txt"
sed '1i[Function]' "$WORK/dump/functions.txt" > "$WORK/dump/Symbols.conf"
"$DEVKIT/bin/LoreMakeThunk.py" --name sodium -o "$WORK/thunk" --lib "$host_lib" --symbols "$WORK/dump/Symbols.conf" --desc "$BENCH/Desc.h" --manifest-host "$BENCH/Manifest_host.cpp" --manifest-guest "$BENCH/Manifest_guest.cpp" --devkit "$DEVKIT" --keep-intermediates -- -I"$NATIVE_PREFIX/include" -I"$NATIVE_PREFIX/include/sodium" > "$WORK/results/thunk.log" 2>&1
host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$DEVKIT/bin/LoreMakeThunk.py" --name errno-shim -o "$WORK/thunk-errno" --lib "$host_libc" --soname errno-shim.so --symbols "$BENCH/ErrnoSymbols.conf" --desc "$BENCH/ErrnoDesc.h" --devkit "$DEVKIT" --keep-intermediates -- -D_GNU_SOURCE > "$WORK/results/errno-thunk.log" 2>&1
ln -sf "$host_libc" "$WORK/thunk-errno/liberrno-shim.so"
prepare_suite() {
  local lane=$1 installed_root=$2 binary=$3 tag cwd data
  tag=$(strings "$binary" | sed -nE 's#^.*\.\./src/([^/)]+\.clean)/test/default/.*\.exp.*$#\1#p' | head -1)
  [[ -n $tag ]] || { echo "Unable to recover installed upstream test data layout" >&2; exit 2; }
  cwd=$WORK/$lane-suite/build/test/default
  data=$WORK/$lane-suite/src/$tag/test/default
  mkdir -p "$cwd" "$data"
  cmake -E copy_directory "$installed_root/source" "$data"
}
first_guest=$(head -1 "$WORK/dump/guest-binaries.txt")
prepare_suite native "$native_root" "$native_root/bin/$(basename "$first_guest")"
prepare_suite hecate "$guest_root" "$first_guest"
run_native() {
  while read -r guest_binary; do
    name=$(basename "$guest_binary")
    native_binary=$native_root/bin/$name
    [[ -x $native_binary ]] || continue
    (cd "$WORK/native-suite/build/test/default" && LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" "$native_binary" >/dev/null 2>&1) || { echo "FAIL: $name"; return 1; }
    echo "PASS: $name"
  done < "$WORK/dump/guest-binaries.txt"
}
run_hecate() {
  while read -r guest_binary; do
    name=$(basename "$guest_binary")
    (cd "$WORK/hecate-suite/build/test/default" && QEMU="$QEMU" DEVKIT="$DEVKIT" HOST_LIB_DIR="$NATIVE_PREFIX/lib" THUNK_DIR="$WORK/thunk" ERRNO_SHIM_DIR="$WORK/thunk-errno" "$QEMU_WRAPPER" "$guest_binary" >/dev/null 2>&1) || { echo "FAIL: $name"; return 1; }
    echo "PASS: $name"
  done < "$WORK/dump/guest-binaries.txt"
}
run_native > "$WORK/results/native-check.log"
run_hecate > "$WORK/results/hecate-check.log"
cmp "$WORK/results/native-check.log" "$WORK/results/hecate-check.log"
cp "$WORK/thunk/.gen/sodium/ThunkStat.json" "$WORK/dump/ThunkStat.json"
count=$(grep -c '^PASS:' "$WORK/results/hecate-check.log")
printf '{"status":"pass","tests":%s}\n' "$count" > "$WORK/results/summary.json"
cat "$WORK/results/summary.json"
