#!/usr/bin/env bash
set -euo pipefail
recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
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
        -h|--help) echo "Usage: $0 [--reference] [--install-only] [--verbose]"; exit 0 ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
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
work=$repo_root/.work/evaluations/rhash
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
    local command=("$vcpkg" install "rhash:$triplet" --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads")
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
meta = {"schema_version": 2, "package": "rhash", "release": "1.4.6", "mechanism": "TLC Only", "workload": "the upstream librhash test program"}
pathlib.Path(sys.argv[1]).write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
summary = {"schema_version": 2, "package": "rhash", "status": "installed", "tests_run": False}
pathlib.Path(sys.argv[2]).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY
if ! $install_only; then
    upstream=$work/upstream
    cmake -E remove_directory "$upstream"
    native_prefix=$work/installed/native/arm64-linux-ae
    guest_prefix=$work/installed/guest/x64-linux-ae
    bench=$overlay/ports/rhash/lorelei
    results=$upstream/results
    dump=$upstream/dump
    mkdir -p "$results" "$dump"
    host_lib=$(find "$native_prefix/lib" -maxdepth 1 -type f -name 'librhash.so.*' -print -quit)
    native_test=$native_prefix/tools/rhash/upstream-tests/test_shared
    guest_test=$guest_prefix/tools/rhash/upstream-tests/test_shared
    [[ -x $native_test && -x $guest_test ]] || { echo "Installed upstream tests are missing" >&2; exit 2; }

    llvm-nm-20 -D --undefined-only --just-symbol-name "$guest_test" \
        | sed 's/@.*//' | sort -u > "$dump/guest-undefined.txt"
    llvm-nm-20 -D --defined-only --format=posix "$host_lib" \
        | awk '$2 == "T" || $2 == "W" {n=$1; sub(/@.*/, "", n); print n}' \
        | sort -u > "$dump/host-functions.txt"
    comm -12 "$dump/guest-undefined.txt" "$dump/host-functions.txt" > "$dump/functions.txt"
    sed '1i[Function]' "$dump/functions.txt" > "$dump/Symbols.conf"

    "$devkit/bin/LoreMakeThunk.py" --name rhash -o "$upstream/thunk" \
        --lib "$host_lib" --symbols "$dump/Symbols.conf" --desc "$bench/Desc.h" \
        --devkit "$devkit" --keep-intermediates --no-auto-link -- \
        -I"$native_prefix/include" > "$results/thunk.log" 2>&1
    ln -sf "$host_lib" "$upstream/thunk/librhash.so"

    shim=$bench/libc-shim
    host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
    "$devkit/bin/LoreMakeThunk.py" --name c-shim -o "$upstream/thunk-libc" \
        --lib "$host_libc" --soname libc-shim.so --symbols "$shim/Symbols.conf" \
        --desc "$shim/Desc.h" --manifest-host "$shim/Manifest_host.cpp" \
        --manifest-guest "$shim/Manifest_guest.cpp" --devkit "$devkit" \
        --keep-intermediates -- -D_GNU_SOURCE -I"$bench/include" \
        > "$results/libc-thunk.log" 2>&1
    ln -sf "$host_libc" "$upstream/thunk-libc/libc-shim.so"

    LD_LIBRARY_PATH="$native_prefix/lib" "$native_test" > "$results/native-test.log" 2>&1
    env LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
        LD_LIBRARY_PATH="$devkit/lib:$native_prefix/lib:$upstream/thunk:$upstream/thunk-libc" \
        "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
        -E "LD_PRELOAD=$upstream/thunk-libc/x86_64/libc-shim.so" \
        -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$upstream/thunk/x86_64" \
        "$guest_test" > "$results/hecate-test.log" 2>&1
    cmp "$results/native-test.log" "$results/hecate-test.log"
    grep -qx 'All sums are working properly!' "$results/hecate-test.log"
    cp "$upstream/thunk/.gen/rhash/ThunkStat.json" "$dump/ThunkStat.json"
    printf '{"status":"pass","upstream_shared_tests":1,"test_scope":"complete configured upstream suite installed by vcpkg"}\n' \
        > "$results/summary.json"
    cat "$results/summary.json"
    mkdir -p "$run_dir/logs/upstream"
    cp -a "$results/." "$run_dir/logs/upstream/"
    cp -a "$dump/." "$run_dir/generated/"
    python3 - "$results/summary.json" "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
data = json.loads(pathlib.Path(sys.argv[1]).read_text())
data.update({"schema_version": 2, "package": "rhash", "tests_run": True, "lanes": ["native", "hecate"]})
pathlib.Path(sys.argv[2]).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
fi
echo "Evidence: $run_dir"
