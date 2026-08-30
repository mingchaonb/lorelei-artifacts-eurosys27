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
work=$repo_root/.work/evaluations/nettle
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
    local command=("$vcpkg" install "nettle:$triplet" --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads")
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
meta = {"schema_version": 2, "package": "nettle", "release": "3.10.2", "mechanism": "TLC Only", "workload": "the configured top-level make check suite"}
pathlib.Path(sys.argv[1]).write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
summary = {"schema_version": 2, "package": "nettle", "status": "installed", "tests_run": False}
pathlib.Path(sys.argv[2]).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY
if ! $install_only; then
    upstream=$work/upstream
    cmake -E remove_directory "$upstream"
    native_prefix=$work/installed/native/arm64-linux-ae
    guest_prefix=$work/installed/guest/x64-linux-ae
    native_tests=$native_prefix/tools/nettle/upstream-tests
    guest_tests=$guest_prefix/tools/nettle/upstream-tests
    bench=$overlay/ports/nettle/lorelei
    results=$upstream/results
    dump=$upstream/dump
    mkdir -p "$results" "$dump"

    # The package manifest is the authoritative test list.  Matching files
    # prove that both vcpkg lanes installed the same configured upstream suite.
    cmp "$native_tests/manifest.tsv" "$guest_tests/manifest.tsv"
    host_lib=$(readlink -f "$native_prefix/lib/libnettle.so.8")

    # Discover the API used by the installed x86-64 tests and generate only
    # the thunks required by that suite.  Metadata objects are package payload,
    # so this stage never reads or compiles the upstream source tree.
    find "$guest_tests" -type f -perm -111 -exec file {} + \
        | awk -F: '/ELF 64-bit LSB.*x86-64/ { print $1 }' \
        > "$dump/x86-tests.txt"
    while read -r binary; do
        llvm-nm-20 -D --undefined-only --just-symbol-name "$binary"
    done < "$dump/x86-tests.txt" | sed 's/@.*//' | sort -u \
        > "$dump/guest-undefined.txt"
    llvm-nm-20 -D --defined-only --format=posix "$host_lib" \
        | awk '$2 == "T" || $2 == "W" { print $1 }' | sed 's/@.*//' | sort -u \
        > "$dump/host-functions.txt"
    comm -12 "$dump/guest-undefined.txt" "$dump/host-functions.txt" \
        > "$dump/functions.txt"
    llvm-nm-20 --undefined-only --just-symbol-name \
        "$guest_tests"/guest-support/*-meta.o "$guest_tests"/guest-support/nettle-meta-*.o \
        | grep -E '^[A-Za-z_][A-Za-z0-9_]*$' | sort -u > "$dump/meta-undefined.txt"
    comm -12 "$dump/meta-undefined.txt" "$dump/host-functions.txt" \
        > "$dump/meta-functions.txt"
    cat "$dump/functions.txt" "$dump/meta-functions.txt" \
        | sort -u | grep -v '^nettle_get_' > "$dump/functions-with-meta.txt"
    sed '1i[Function]' "$dump/functions-with-meta.txt" > "$dump/Symbols.conf"

    "$devkit/bin/LoreMakeThunk.py" --name nettle -o "$upstream/thunk" \
        --lib "$host_lib" --symbols "$dump/Symbols.conf" \
        --desc "$native_tests/Desc.h" --manifest-host "$bench/Manifest_host.cpp" \
        --devkit "$devkit" --keep-intermediates -- \
        -I"$native_prefix/include" -I"$native_prefix/include/nettle" \
        -I"$native_tests/include" > "$results/thunk-build.log" 2>&1

    # Link package-provided guest metadata into the generated GTL.  These are
    # read-only algorithm descriptors and two internal helpers, not rebuilt
    # upstream tests.
    "$devkit/bin/x86_64-linux-gnu-clang++" \
        --sysroot="$devkit/x86_64/sysroot" -shared -std=gnu++20 -fPIC \
        -fno-exceptions -fno-rtti -I"$devkit/x86_64/include" \
        -I"$upstream/thunk/.gen/nettle" -I"$native_prefix/include" \
        -I"$native_prefix/include/nettle" -I"$native_tests/include" \
        -DLORE_THUNK_NEXT_LIBRARY='"../libnettle_HTL.so"' \
        "$upstream/thunk/.gen/nettle/Thunk_guest.cpp" \
        "$guest_tests"/guest-support/*-meta.o \
        "$guest_tests"/guest-support/nettle-meta-*.o \
        "$guest_tests"/guest-support/chacha-core-internal.o \
        "$guest_tests"/guest-support/write-be32.o \
        -o "$upstream/thunk/x86_64/libnettle.so" \
        -L"$devkit/x86_64/lib" -lLoreGuestRT -Wl,-soname,libnettle.so.8 \
        >> "$results/thunk-build.log" 2>&1
    ln -sf libnettle.so "$upstream/thunk/x86_64/libnettle.so.8"

    # dlopen-test deliberately opens a relative DSO.  Recreate that installed
    # layout for both lanes while keeping the generated GTL and HTL together.
    ln -sf "$host_lib" "$native_tests/libnettle.so"
    ln -sf "$upstream/thunk/x86_64/libnettle.so" "$guest_tests/libnettle.so"
    ln -sf "$upstream/thunk/libnettle_HTL.so" "$guest_tests/libnettle_HTL.so"
    ln -sf "$upstream/thunk/libnettle_HTL.so" "$(dirname "$guest_tests")/libnettle_HTL.so"

    run_groups() {
        local lane=$1 root=$2 group
        : > "$results/$lane.log"
        for group in tools testsuite examples; do
            mapfile -t names < <(awk -F '\t' -v group="$group" '$1 == group { print $2 }' "$root/manifest.tsv")
            printf '[%s]\n' "$group" | tee -a "$results/$lane.log"
            if [[ $lane == native ]]; then
                (
                    cd "$root/$group"
                    TEST_SHLIB_DIR="$native_prefix/lib" srcdir="$root/$group" \
                        "$root/run-tests" "${names[@]}"
                ) 2>&1 | tee -a "$results/$lane.log"
            else
                (
                    cd "$root/$group"
                    QEMU="$qemu" DEVKIT="$devkit" LORE_AE_HECATE=1 \
                        HOST_LIB_DIR="$native_prefix/lib" THUNK_DIR="$upstream/thunk" \
                        TEST_SHLIB_DIR="$upstream/thunk/x86_64" srcdir="$root/$group" \
                        EMULATOR="$bench/QEMUWrapper.sh" \
                        "$root/run-tests" "${names[@]}"
                ) 2>&1 | tee -a "$results/$lane.log"
            fi
        done
        grep -E '^(PASS|SKIP|FAIL):' "$results/$lane.log" > "$results/$lane.normalized"
    }

    run_groups native "$native_tests"
    run_groups hecate "$guest_tests"
    cmp "$results/native.normalized" "$results/hecate.normalized"
    passed=$(grep -c '^PASS:' "$results/hecate.normalized")
    skipped=$(grep -c '^SKIP:' "$results/hecate.normalized")
    failed=$(grep -c '^FAIL:' "$results/hecate.normalized" || true)
    [[ $failed -eq 0 ]]
    cp "$upstream/thunk/.gen/nettle/ThunkStat.json" "$dump/ThunkStat.json"

    python3 - "$results/summary.json" "$passed" "$skipped" "$failed" <<'PY'
import json, pathlib, sys
output, passed, skipped, failed = sys.argv[1:]
data = {
    "status": "pass" if int(failed) == 0 else "fail",
    "release": "3.10.2",
    "tests_passed": int(passed),
    "tests_skipped": int(skipped),
    "tests_failed": int(failed),
    "test_scope": "complete configured upstream suite installed by vcpkg",
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    cat "$results/summary.json"
    mkdir -p "$run_dir/logs/upstream"
    cp -a "$results/." "$run_dir/logs/upstream/"
    cp -a "$dump/." "$run_dir/generated/"
    python3 - "$results/summary.json" "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
data.update({"schema_version": 2, "package": "nettle", "tests_run": True, "lanes": ["native", "hecate"]})
pathlib.Path(sys.argv[2]).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
fi
echo "Evidence: $run_dir"
