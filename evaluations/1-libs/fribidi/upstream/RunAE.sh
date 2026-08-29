#!/usr/bin/env bash

set -euo pipefail

root=$(cd "$(dirname "$0")/../../../.." && pwd)
bench=$(cd "$(dirname "$0")" && pwd)
devkit=${DEVKIT:-"$root/build/install"}
qemu=${QEMU:-"$devkit/bin/qemu-x86_64"}
src=${FRIBIDI_SOURCE:-"$root/../ae-libs/fribidi"}
work=${WORK:-"$root/build/ae-fribidi"}
nm=${NM:-llvm-nm-20}
jobs=${JOBS:-8}
expected_commit=68162babff4f39c4e2dc164a5e825af93bda9983

actual_commit=$(git -C "$src" rev-parse HEAD)
if [[ "$actual_commit" != "$expected_commit" ]]; then
    echo "FriBidi source must be v1.0.16 at $expected_commit" >&2
    exit 1
fi

cmake -E remove_directory "$work"
mkdir -p "$work/dump" "$work/results"
cp "$bench/QEMUWrapper.sh" "$work/qemu-wrapper.sh"
chmod +x "$work/qemu-wrapper.sh"

if grep -RInE --include='*.c' '\b(setjmp|sigsetjmp|longjmp|siglongjmp)\b' \
    "$src/lib" > "$work/dump/setjmp-audit.txt"; then
    echo "FriBidi production source uses a forbidden non-local jump" >&2
    exit 1
fi

meson setup "$work/host" "$src" \
    -Dbuildtype=release \
    -Ddefault_library=shared \
    -Dtests=true \
    -Ddocs=false \
    -Dbin=true
meson compile -C "$work/host" -j "$jobs"
meson test -C "$work/host" --print-errorlogs \
    > "$work/results/native-test.log" 2>&1

cat > "$work/x86_64.cross" <<EOF
[binaries]
c = '/usr/bin/clang-20'
ar = 'llvm-ar-20'
strip = 'llvm-strip-20'
exe_wrapper = '$work/qemu-wrapper.sh'

[built-in options]
c_args = ['--target=x86_64-pc-linux-gnu', '--sysroot=$devkit/x86_64/sysroot', '-O2']
c_link_args = ['--target=x86_64-pc-linux-gnu', '--sysroot=$devkit/x86_64/sysroot', '-fuse-ld=lld']

[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'
EOF

QEMU="$qemu" DEVKIT="$devkit" meson setup "$work/guest" "$src" \
    --cross-file "$work/x86_64.cross" \
    -Dbuildtype=release \
    -Ddefault_library=shared \
    -Dtests=true \
    -Ddocs=false \
    -Dbin=true
QEMU="$qemu" DEVKIT="$devkit" meson compile -C "$work/guest" -j "$jobs"

host_lib="$work/host/lib/libfribidi.so.0.4.0"
guest_bins=(
    "$work/guest/bin/fribidi"
    "$work/guest/test/unicode-conformance/BidiTest"
    "$work/guest/test/unicode-conformance/BidiCharacterTest"
)

readelf -Ws "$host_lib" > "$work/dump/host-symbols.txt"
readelf -d "$host_lib" > "$work/dump/host-dynamic.txt"
awk '$4 == "OBJECT" || $4 == "TLS" { print }' "$work/dump/host-symbols.txt" \
    > "$work/dump/host-data-tls.txt"
file "$host_lib" "${guest_bins[@]}" > "$work/dump/file.txt"

: > "$work/dump/guest-undefined.txt"
for binary in "${guest_bins[@]}"; do
    "$nm" -D --undefined-only --just-symbol-name "$binary" \
        | sed 's/@.*//' >> "$work/dump/guest-undefined.txt"
done
sort -u -o "$work/dump/guest-undefined.txt" "$work/dump/guest-undefined.txt"
"$nm" -D --defined-only --format=posix "$host_lib" \
    | awk '$2 == "T" || $2 == "W" { name = $1; sub(/@.*/, "", name); print name }' \
    | sort -u > "$work/dump/host-functions.txt"
comm -12 "$work/dump/guest-undefined.txt" "$work/dump/host-functions.txt" \
    > "$work/dump/functions.txt"
printf '[Function]\n' > "$work/dump/Symbols.conf"
cat "$work/dump/functions.txt" >> "$work/dump/Symbols.conf"

(cd "$work/host" && "$devkit/bin/LoreTLC" dump \
    -c "$work/dump/Symbols.conf" \
    -p . \
    -o "$work/dump/Desc.dump.h")

"$devkit/bin/LoreMakeThunk.py" \
    --name fribidi \
    -o "$work/thunk" \
    --lib "$host_lib" \
    --symbols "$work/dump/Symbols.conf" \
    --desc "$bench/Desc.h" \
    --devkit "$devkit" \
    --keep-intermediates \
    -- \
    -I"$src/lib" \
    -I"$work/host/lib" \
    -I"$work/host/gen.tab"

"$devkit/bin/x86_64-linux-gnu-clang" \
    --sysroot="$devkit/x86_64/sysroot" \
    -shared -fPIC "$bench/GuestMetadata.c" \
    -o "$work/libFriBidiGuestMetadata.so"

run_full() {
    env LD_LIBRARY_PATH="$devkit/lib" \
        "$qemu" -L "$devkit/x86_64/sysroot" \
        -E "LD_LIBRARY_PATH=$work/guest/lib" "$@"
}

run_hecate() {
    env LD_LIBRARY_PATH="$devkit/lib:$work/host/lib:$work/thunk" \
        "$qemu" -L "$devkit/x86_64/sysroot" \
        -E LD_BIND_NOW=1 \
        -E "LD_PRELOAD=$work/libFriBidiGuestMetadata.so" \
        -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64" "$@"
}

run_lane() {
    local lane=$1
    local runner=run_full
    if [[ "$lane" == hecate ]]; then
        runner=run_hecate
    fi
    local output=$work/results/$lane.log
    local start end
    : > "$output"
    start=$(date +%s%N)

    while read -r charset suffix; do
        local name=${charset}_${suffix}
        "$runner" "$work/guest/bin/fribidi" --test --charset "$charset" \
            "$src/test/test_${name}.input" > "$work/results/$name-$lane.actual"
        cmp "$src/test/test_${name}.reference" "$work/results/$name-$lane.actual"
        echo "PASS $name" >> "$output"
    done <<'EOF'
CapRTL explicit
CapRTL implicit
CapRTL isolate
ISO8859-8 hebrew
UTF-8 persian
UTF-8 reordernsm
EOF

    "$runner" "$work/guest/test/unicode-conformance/BidiTest" \
        "$src/test/unicode-conformance/BidiTest.txt" >> "$output" 2>&1
    echo 'PASS BidiTest' >> "$output"
    "$runner" "$work/guest/test/unicode-conformance/BidiCharacterTest" \
        "$src/test/unicode-conformance/BidiCharacterTest.txt" >> "$output" 2>&1
    echo 'PASS BidiCharacterTest' >> "$output"

    end=$(date +%s%N)
    awk -v start="$start" -v end="$end" \
        'BEGIN { printf "elapsed=%.3f exit=0\n", (end - start) / 1000000000 }' \
        > "$work/results/$lane.time"
}

run_lane hecate

function_count=$(wc -l < "$work/dump/functions.txt")
printf '{\n  "status": "pass",\n  "source_commit": "%s",\n  "functions": %s,\n  "tests": 8\n}\n' \
    "$actual_commit" "$function_count" > "$work/results/summary.json"

cat "$work/results/summary.json"
cat "$work/results/hecate.time"
