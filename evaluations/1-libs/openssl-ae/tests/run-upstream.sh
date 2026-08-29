#!/usr/bin/env bash

set -euo pipefail

: "${DEVKIT:?}" "${QEMU:?}" "${WORK:?}" "${BENCH:?}" "${NATIVE_PREFIX:?}" "${GUEST_PREFIX:?}"
bench=$BENCH
devkit=$DEVKIT
qemu=$QEMU
work=$WORK
nm=${NM:-llvm-nm-20}

cmake -E remove_directory "$work"
mkdir -p "$work/dump/crypto" "$work/dump/ssl" "$work/results"
test_root=$NATIVE_PREFIX/tools/openssl-ae/upstream-tests
host_crypto=$NATIVE_PREFIX/lib/libcrypto.so.3
host_ssl=$NATIVE_PREFIX/lib/libssl.so.3
native_cli=$NATIVE_PREFIX/bin/openssl
guest_cli=$GUEST_PREFIX/bin/openssl
for required in "$host_crypto" "$host_ssl" "$native_cli" "$guest_cli" \
        "$test_root/build/libcrypto.ld" "$test_root/build/libssl.ld"; do
    [[ -e $required ]] || { echo "Installed OpenSSL payload missing: $required" >&2; exit 2; }
done

"$nm" -D --undefined-only --just-symbol-name "$guest_cli" \
    | sed 's/@.*//' \
    | sort -u \
    > "$work/dump/guest-undefined.txt"

collect_functions() {
    local library=$1
    local output=$2
    "$nm" -D --defined-only --format=posix "$library" \
        | awk '$2 == "T" || $2 == "W" { name = $1; sub(/@.*/, "", name); print name }' \
        | sort -u > "$output/host-functions.txt"
    comm -12 "$work/dump/guest-undefined.txt" "$output/host-functions.txt" \
        > "$output/functions.txt"
    printf '[Function]\n' > "$output/Symbols.conf"
    cat "$output/functions.txt" >> "$output/Symbols.conf"
}

collect_functions "$host_crypto" "$work/dump/crypto"
collect_functions "$host_ssl" "$work/dump/ssl"

"$devkit/bin/LoreMakeThunk.py" \
    --name crypto \
    -o "$work/thunk-crypto" \
    --lib "$host_crypto" \
    --symbols "$work/dump/crypto/Symbols.conf" \
    --desc "$bench/Desc.h" \
    --manifest-host "$bench/crypto/Manifest_host.cpp" \
    --manifest-guest "$bench/crypto/Manifest_guest.cpp" \
    --devkit "$devkit" \
    --keep-intermediates \
    --gtl-alias=libcrypto.so.3 \
    --gtl-arg="-Wl,--undefined-version" \
    --gtl-arg="-Wl,--version-script=$test_root/build/libcrypto.ld" \
    -- \
    -I"$NATIVE_PREFIX/include" \
    -I"$bench/include"

"$devkit/bin/LoreMakeThunk.py" \
    --name ssl \
    -o "$work/thunk-ssl" \
    --lib "$host_ssl" \
    --symbols "$work/dump/ssl/Symbols.conf" \
    --desc "$bench/Desc.h" \
    --manifest-host "$bench/ssl/Manifest_host.cpp" \
    --manifest-guest "$bench/ssl/Manifest_guest.cpp" \
    --devkit "$devkit" \
    --keep-intermediates \
    --gtl-alias=libssl.so.3 \
    --gtl-arg="-Wl,--undefined-version" \
    --gtl-arg="-Wl,--version-script=$test_root/build/libssl.ld" \
    -- \
    -I"$NATIVE_PREFIX/include" \
    -I"$bench/include"

host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
"$devkit/bin/LoreMakeThunk.py" \
    --name c-shim \
    -o "$work/thunk-libc-shim" \
    --lib "$host_libc" \
    --soname libc-shim.so \
    --symbols "$bench/libc-shim/Symbols.conf" \
    --desc "$bench/libc-shim/Desc.h" \
    --manifest-host "$bench/libc-shim/Manifest_host.cpp" \
    --manifest-guest "$bench/libc-shim/Manifest_guest.cpp" \
    --devkit "$devkit" \
    --keep-intermediates \
    -- \
    -D_GNU_SOURCE \
    -I"$bench/include"
ln -sf "$host_libc" "$work/thunk-libc-shim/libc-shim.so"

env OPENSSL_CONF=/dev/null OPENSSL_MODULES="$NATIVE_PREFIX/lib/ossl-modules" \
    LD_LIBRARY_PATH="$NATIVE_PREFIX/lib" \
    "$native_cli" speed -elapsed -seconds 1 -bytes 16384 sha256 \
    > "$work/results/native-speed.log" 2>&1

env \
    OPENSSL_CONF=/dev/null \
    OPENSSL_MODULES="$NATIVE_PREFIX/lib/ossl-modules" \
    LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$devkit/lib:$NATIVE_PREFIX/lib:$work/thunk-crypto:$work/thunk-ssl:$work/thunk-libc-shim" \
    "$qemu" -L "$devkit/x86_64/sysroot" \
    -U LD_PRELOAD \
    -E "LD_BIND_NOW=1" \
    -E "LD_PRELOAD=$work/thunk-libc-shim/x86_64/libc-shim.so" \
    -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk-ssl/x86_64:$work/thunk-crypto/x86_64" \
    -E "OPENSSL_CONF=/dev/null" \
    -E "OPENSSL_MODULES=$NATIVE_PREFIX/lib/ossl-modules" \
    "$guest_cli" speed -elapsed -seconds 1 -bytes 16384 sha256 \
    > "$work/results/hecate-speed.log" 2>&1
grep -q '^sha256[[:space:]]' "$work/results/native-speed.log"
grep -q '^sha256[[:space:]]' "$work/results/hecate-speed.log"
cp "$work/thunk-crypto/.gen/crypto/ThunkStat.json" "$work/dump/crypto/ThunkStat.json"
cp "$work/thunk-ssl/.gen/ssl/ThunkStat.json" "$work/dump/ssl/ThunkStat.json"
crypto_functions=$(wc -l < "$work/dump/crypto/functions.txt")
ssl_functions=$(wc -l < "$work/dump/ssl/functions.txt")
cat > "$work/results/summary.json" <<EOF
{
  "status": "pass",
  "release": "3.0.22",
  "workload": "openssl speed -elapsed -seconds 1 -bytes 16384 sha256",
  "crypto_functions": $crypto_functions,
  "ssl_functions": $ssl_functions,
  "scope": "Figure 18 fixed speed workload, not the full OpenSSL test suite"
}
EOF
cat "$work/results/summary.json"
