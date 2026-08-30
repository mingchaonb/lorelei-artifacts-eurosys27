#!/usr/bin/env bash
set -euo pipefail
recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
overlay=$repo_root/vcpkg-overlay
reference=false
install_only=false
verbose=false
args=()
while (($#)); do
    case $1 in
        --reference) reference=true ;;
        --install-only) install_only=true ;;
        --verbose) verbose=true ;;
        -h|--help) echo "Usage: $0 [--reference] [--install-only] [--verbose] /path/to/lorelei-devkit"; exit 0 ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) args+=("$1") ;;
    esac
    shift
done
[[ ${#args[@]} == 1 ]] || { echo "Expected one devkit path" >&2; exit 2; }
devkit=$(realpath "${args[0]}")
qemu=$(realpath -m "${QEMU:-$devkit/bin/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg first" >&2; exit 2; }
[[ -x $devkit/bin/x86_64-linux-gnu-clang ]] || { echo "Invalid devkit: $devkit" >&2; exit 2; }
if ! $install_only; then
    [[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
    [[ -e $devkit/lib/libLoreQEMUThreadHook.so ]] || { echo "Missing Hecate thread hook in devkit" >&2; exit 2; }
    nm -D "$qemu" | grep 'qemu_lorelei_reentry' > /dev/null || { echo "QEMU does not provide qemu_lorelei_reentry: $qemu" >&2; exit 2; }
fi
kind=results
$reference && kind=reference-results
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$recipe_dir/$kind/$run_id
work=$repo_root/.work/evaluations/libtasn1
[[ ! -e $run_dir ]] || { echo "Evidence exists: $run_dir" >&2; exit 2; }
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to reuse unmarked work directory: $work" >&2
    exit 2
fi
mkdir -p "$run_dir/logs/preparation" "$run_dir/generated" "$work"
touch "$work/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1
export LORELEI_DEVKIT=$devkit
install_lane() {
    local lane=$1 triplet=$2
    local log=$run_dir/logs/preparation/vcpkg-$lane.log
    local command=("$vcpkg" install "libtasn1:$triplet" --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads")
    if $verbose; then
        "${command[@]}" 2>&1 | tee "$log"
    else
        "${command[@]}" >"$log" 2>&1
    fi
}
install_lane native arm64-linux-ae
install_lane guest x64-linux-ae
find "$work/installed/native/arm64-linux-ae/lib" "$work/installed/guest/x64-linux-ae/lib" -maxdepth 1 -type f -name '*.so*' -print -exec file {} \; -exec readelf -d {} \; -exec readelf -Ws {} \; >"$run_dir/generated/shared-library-audit.txt"
python3 - "$run_dir/meta.json" "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
meta = {"schema_version": 2, "package": "libtasn1", "release": "4.21.0", "mechanism": "TLC Only", "workload": "31 regular tests and 9 configured fuzz regression tests"}
pathlib.Path(sys.argv[1]).write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
summary = {"schema_version": 2, "package": "libtasn1", "status": "installed", "tests_run": False}
pathlib.Path(sys.argv[2]).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY
if ! $install_only; then
    upstream=$work/upstream
    cmake -E remove_directory "$upstream"
    native_prefix=$work/installed/native/arm64-linux-ae
    guest_prefix=$work/installed/guest/x64-linux-ae
    native_tests=$native_prefix/tools/libtasn1/upstream-tests
    guest_tests=$guest_prefix/tools/libtasn1/upstream-tests
    bench=$overlay/ports/libtasn1/lorelei
    libc_shim=$bench/libc-shim
    results=$upstream/results
    dump=$upstream/dump
    mkdir -p "$results" "$dump"

    cmp "$native_tests/manifest.tsv" "$guest_tests/manifest.tsv"
    [[ $(wc -l < "$native_tests/manifest.tsv") -eq 40 ]] || {
        echo "Installed libtasn1 manifest does not contain all 40 configured tests" >&2
        exit 2
    }

    host_lib=$(find "$native_prefix/lib" -maxdepth 1 -type f -name 'libtasn1.so.*' -print -quit)
    [[ -n $host_lib ]] || { echo "Installed native libtasn1 DSO is missing" >&2; exit 2; }
    find "$guest_tests/fuzz" "$guest_tests/tests" "$guest_prefix/tools/libtasn1/bin" \
        -maxdepth 1 -type f -perm -111 -exec file {} + \
        | awk -F: '/ELF 64-bit LSB.*x86-64/ { print $1 }' > "$dump/x86-tests.txt"
    while read -r binary; do
        llvm-nm-20 -D --undefined-only --just-symbol-name "$binary"
    done < "$dump/x86-tests.txt" | sed 's/@.*//' | sort -u > "$dump/guest-undefined.txt"
    llvm-nm-20 -D --defined-only --format=posix "$host_lib" \
        | awk '$2 == "T" || $2 == "W" { name=$1; sub(/@.*/, "", name); print name }' \
        | sort -u > "$dump/host-functions.txt"
    comm -12 "$dump/guest-undefined.txt" "$dump/host-functions.txt" > "$dump/functions.txt"
    sed '1i[Function]' "$dump/functions.txt" > "$dump/Symbols.conf"

    "$devkit/bin/LoreMakeThunk.py" \
        --name tasn1 -o "$upstream/thunk" --lib "$host_lib" \
        --symbols "$dump/Symbols.conf" --desc "$bench/Desc.h" \
        --manifest-guest "$bench/Manifest_guest.cpp" \
        --devkit "$devkit" --keep-intermediates -- \
        -I"$native_prefix/include" -I"$bench/include" \
        > "$results/thunk-build.log" 2>&1

    # Shell tests exchange FILE pointers with the command-line tools.  The
    # package-local libc shim keeps those streams on the guest side while the
    # libtasn1 calls continue through the generated thunk.
    host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
    "$devkit/bin/LoreMakeThunk.py" \
        --name c-shim -o "$upstream/thunk-libc-shim" --lib "$host_libc" \
        --soname libc-shim.so --symbols "$libc_shim/Symbols.conf" \
        --desc "$libc_shim/Desc.h" --manifest-host "$libc_shim/Manifest_host.cpp" \
        --manifest-guest "$libc_shim/Manifest_guest.cpp" \
        --devkit "$devkit" --keep-intermediates -- \
        -D_GNU_SOURCE -I"$bench/include" > "$results/libc-thunk-build.log" 2>&1
    ln -sf "$host_libc" "$upstream/thunk-libc-shim/libc-shim.so"

    prepare_lane() {
        local lane=$1 prefix=$2 installed=$3 root
        root=$upstream/$lane
        mkdir -p "$root/fuzz" "$root/tests" "$root/examples" "$root/lib" "$root/src/.libs"
        cp -a "$installed/fuzz/." "$root/fuzz/"
        cp -a "$installed/tests/." "$root/tests/"
        cp -a "$installed/tests-source/." "$root/tests/"
        cp -a "$installed/examples-source/." "$root/examples/"
        cp -a "$installed/lib-source/." "$root/lib/"
        for tool in asn1Parser asn1Coding asn1Decoding; do
            if [[ $lane == native ]]; then
                ln -sf "$prefix/tools/libtasn1/bin/$tool" "$root/src/$tool"
            else
                cp "$bench/ToolWrapper.sh" "$root/src/$tool"
                chmod +x "$root/src/$tool"
                ln -sf "$prefix/tools/libtasn1/bin/$tool" "$root/src/.libs/$tool"
            fi
        done
    }
    prepare_lane native "$native_prefix" "$native_tests"
    prepare_lane hecate "$guest_prefix" "$guest_tests"

    run_lane() {
        local lane=$1 prefix=$2 root group name test_path
        root=$upstream/$lane
        local tests_source=$root/tests
        local common_env=(
            "ASN1PARSER=$tests_source/Test_parser.asn"
            "ASN1TREE=$tests_source/Test_tree.asn"
            "ASN1CHOICE=$tests_source/choice.asn"
            "ASN1CODINGDECODING2=$tests_source/coding-decoding2.asn"
            "ASN1PKIX=$tests_source/pkix.asn"
            "ASN1SETOF=$tests_source/setof.asn"
            "ASN1CRLDER=$tests_source/crl.der"
            "ASN1INDEF=$tests_source/TestIndef.p12"
            "ASN1INDEF2=$tests_source/TestIndef2.p12"
            "ASN1INDEF3=$tests_source/TestIndef3.der"
            "ASN1ENCODING=$tests_source/Test_encoding.asn"
            "ASN1CHOICE_OCSP=$tests_source/pkix.asn"
            "ASN1CHOICE_OCSP_DATA=$tests_source/ocsp.der"
            "ASN1_RESPONSE_OCSP_DATA=$tests_source/ocsp-basic-response.der"
            "ASN1_MSCAT=$tests_source/mscat.asn"
            "ASN1_SPC_PE_IMAGE_DATA=$tests_source/spc_pe_image_data.der"
            "THREADSAFETY_FILES=$(find "$root/lib" -type f -name '*.c' -print | tr '\n' ' ')"
            "EXEEXT=" "VALGRIND=" "LIBTOOL=" "RUN_EXPENSIVE_TESTS=no"
        )
        : > "$results/$lane.log"
        while IFS=$'\t' read -r group name; do
            test_path=$root/$group/$name
            printf 'RUN: %s/%s\n' "$group" "$name" | tee -a "$results/$lane.log"
            if [[ $name == *.sh ]]; then
                if [[ $lane == native ]]; then
                    (cd "$root/tests" && env "${common_env[@]}" \
                        LD_LIBRARY_PATH="$prefix/lib" srcdir="$root/tests" "$test_path") \
                        >> "$results/$lane.log" 2>&1
                else
                    (cd "$root/tests" && env "${common_env[@]}" srcdir="$root/tests" \
                        QEMU="$qemu" DEVKIT="$devkit" QEMU_WRAPPER="$bench/QEMUWrapper.sh" \
                        LORE_AE_HECATE=1 HOST_LIB_DIR="$native_prefix/lib" \
                        THUNK_DIR="$upstream/thunk" LIBC_SHIM_DIR="$upstream/thunk-libc-shim" \
                        GUEST_LIB_DIR="$guest_prefix/lib" "$test_path") \
                        >> "$results/$lane.log" 2>&1
                fi
            elif [[ $lane == native ]]; then
                env "${common_env[@]}" LD_LIBRARY_PATH="$prefix/lib" "$test_path" \
                    >> "$results/$lane.log" 2>&1
            else
                env "${common_env[@]}" QEMU="$qemu" DEVKIT="$devkit" LORE_AE_HECATE=1 \
                    HOST_LIB_DIR="$native_prefix/lib" THUNK_DIR="$upstream/thunk" \
                    LIBC_SHIM_DIR="$upstream/thunk-libc-shim" GUEST_LIB_DIR="$guest_prefix/lib" \
                    "$bench/QEMUWrapper.sh" "$test_path" >> "$results/$lane.log" 2>&1
            fi
            printf 'PASS: %s/%s\n' "$group" "$name" | tee -a "$results/$lane.log"
        done < "$native_tests/manifest.tsv"
        grep '^PASS:' "$results/$lane.log" > "$results/$lane.normalized"
    }

    run_lane native "$native_prefix"
    run_lane hecate "$guest_prefix"
    cmp "$results/native.normalized" "$results/hecate.normalized"
    passed=$(wc -l < "$results/hecate.normalized")
    [[ $passed -eq 40 ]]
    cp "$upstream/thunk/.gen/tasn1/ThunkStat.json" "$dump/ThunkStat.json"
    printf '{"status":"pass","upstream_tests_passed":%s,"test_scope":"complete configured upstream suite installed by vcpkg"}\n' \
        "$passed" > "$results/summary.json"
    cat "$results/summary.json"
    mkdir -p "$run_dir/logs/upstream"
    cp -a "$results/." "$run_dir/logs/upstream/"
    cp -a "$dump/." "$run_dir/generated/"
    python3 - "$results/summary.json" "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
data.update({"schema_version": 2, "package": "libtasn1", "tests_run": True, "lanes": ["native", "hecate"]})
pathlib.Path(sys.argv[2]).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
fi
echo "Evidence: $run_dir"
