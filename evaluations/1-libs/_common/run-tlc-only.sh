#!/usr/bin/env bash
set -euo pipefail

package=$1
thunk_name=$2
soname=$3
shift 3
reference=false
install_only=false
verbose=false
positional=()
while (($#)); do
    case $1 in
        --reference) reference=true ;;
        --install-only) install_only=true ;;
        --verbose) verbose=true ;;
        -h|--help) echo "Usage: run.sh [--reference] [--install-only] [--verbose]"; exit 0 ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../$package" 2>/dev/null && pwd || true)
if [[ -z $recipe_dir ]]; then recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../sdl2-ttf" && pwd); fi
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
export LORELEI_DEVKIT=$devkit
common_dir=$repo_root/evaluations/common
overlay=$repo_root/vcpkg-overlay
vcpkg=$repo_root/vcpkg/vcpkg
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
work=$repo_root/.work/evaluations/$package
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; result_kind=reference; fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id

[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg before running this recipe" >&2; exit 2; }
[[ -x $devkit/bin/LoreMakeThunk.py ]] || { echo "Missing LoreMakeThunk.py in devkit" >&2; exit 2; }
if ! $install_only; then
    [[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
    [[ -e $devkit/lib/libLoreQEMUThreadHook.so ]] || { echo "Missing Hecate thread hook in devkit" >&2; exit 2; }
    nm -D "$qemu" | grep qemu_lorelei_reentry > /dev/null || { echo "QEMU does not provide qemu_lorelei_reentry: $qemu" >&2; exit 2; }
fi
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then echo "Refusing unmarked work directory: $work" >&2; exit 2; fi
# Keep the per-package vcpkg roots so later runs can reuse ABI-matching installs.
mkdir -p "$work" "$run_dir"/{generated,logs/preparation,logs/native,logs/hecate}
touch "$work/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

run_logged() {
    local log=$1 status
    shift
    printf '  $'
    printf ' %q' "$@"
    printf '\n'
    if ! $verbose; then "$@" >"$log" 2>&1; return; fi
    set +e
    "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    set -e
    return "$status"
}

{
    date -u --iso-8601=seconds
    uname -a
    cat /etc/os-release
    lscpu
    free -h
    uptime
    "$vcpkg" version
    if ! $install_only; then sha256sum "$qemu"; fi
} >"$run_dir/environment.txt" 2>&1
python3 - "$run_dir/meta.json" "$run_id" "$result_kind" "$package" "$devkit" "$qemu" "$install_only" <<'PY'
import datetime, json, pathlib, sys
output, run_id, kind, package, devkit, qemu, install_only = sys.argv[1:]
mechanism = "TLC + zero-hit HLR audit" if package == "sdl2-ttf" else "TLC Only"
data = {"schema_version": 2, "experiment_id": run_id, "package": package, "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": mechanism, "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

# Count repository-owned TLC configuration before package preparation.
port_dir=$overlay/ports/$package
configuration_files=("$port_dir/lorelei/Desc.h" "$port_dir/lorelei/Symbols.conf")
for manifest in "$port_dir/lorelei/Manifest_guest.cpp" "$port_dir/lorelei/Manifest_host.cpp"; do
    if [[ -f $manifest ]]; then configuration_files+=("$manifest"); fi
done
run_logged "$run_dir/logs/preparation/configuration-loc.log" \
    python3 "$repo_root/evaluations/common/tools/count-configuration-loc.py" \
    --root "$repo_root" --output "$run_dir/generated/configuration-loc.json" "${configuration_files[@]}"

export VCPKG_MAX_CONCURRENCY
VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
    local lane=$1 triplet=$2
    local packages=("$package:$triplet")
    if [[ $package == sdl2-ttf && $lane == hecate ]]; then
        packages=('sdl2[hlr]' 'sdl2-ttf[hlr]')
    fi
    run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "${packages[@]}" \
        --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" \
        --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" \
        --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}

install_lane native arm64-linux-ae
install_lane guest x64-linux-ae
if [[ $package == sdl2-ttf ]]; then install_lane hecate arm64-linux-ae; fi
native_prefix=$work/installed/native/arm64-linux-ae
host_prefix=$native_prefix
if [[ $package == sdl2-ttf ]]; then host_prefix=$work/installed/hecate/arm64-linux-ae; fi
guest_prefix=$work/installed/guest/x64-linux-ae
host_library=$(find "$host_prefix/lib" -maxdepth 1 \( -type f -o -type l \) -name "$soname*" | head -1)
[[ -n $host_library ]] || { echo "Host library not found for $soname" >&2; exit 1; }
native_suite=$native_prefix/tools/$package/upstream-tests
guest_suite=$guest_prefix/tools/$package/upstream-tests
[[ -d $native_suite/bin && -d $guest_suite/bin ]] || { echo "Installed upstream tests not found for $package" >&2; exit 1; }
mapfile -t native_tests < <(find "$native_suite/bin" -maxdepth 1 -type f -perm -111 -printf '%f\n' | sort)
mapfile -t guest_tests < <(find "$guest_suite/bin" -maxdepth 1 -type f -perm -111 -printf '%f\n' | sort)
[[ ${native_tests[*]} == "${guest_tests[*]}" ]] || { echo "Native and guest test inventories differ" >&2; exit 1; }
case $package in
    libmaxminddb) expected_tests=26 ;;
    qrencode) expected_tests=12 ;;
    libstemmer) expected_tests=1 ;;
    libthai) expected_tests=9 ;;
    libunibreak) expected_tests=1 ;;
    libyaml) expected_tests=2 ;;
    sdl2-ttf) expected_tests=1 ;;
    utf8proc) expected_tests=10 ;;
esac
[[ ${#guest_tests[@]} == "$expected_tests" ]] || { echo "Expected $expected_tests installed test binaries for $package, found ${#guest_tests[@]}" >&2; exit 1; }
excluded_tests=()

nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || command -v nm)
: >"$run_dir/generated/guest-undefined.txt"
for test_name in "${guest_tests[@]}"; do
    "$nm_tool" -D --undefined-only --just-symbol-name "$guest_suite/bin/$test_name" \
        | sed 's/@.*//' >>"$run_dir/generated/guest-undefined.txt"
done
if [[ -d $guest_suite/lib ]]; then
    while IFS= read -r helper_library; do
        "$nm_tool" -D --undefined-only --just-symbol-name "$helper_library" \
            | sed 's/@.*//' >>"$run_dir/generated/guest-undefined.txt"
    done < <(find "$guest_suite/lib" -maxdepth 1 -type f -name '*.so*' | sort)
fi
sort -u -o "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/guest-undefined.txt"
"$nm_tool" -D --defined-only --format=posix "$host_library" \
    | awk '$2 == "T" || $2 == "W" { name=$1; sub(/@.*/, "", name); print name }' \
    | sort -u >"$run_dir/generated/host-functions.txt"
comm -12 "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/host-functions.txt" \
    >"$run_dir/generated/functions.txt"
{ echo '[Function]'; cat "$run_dir/generated/functions.txt"; } >"$run_dir/generated/Symbols.conf"
[[ -s $run_dir/generated/functions.txt ]] || { echo "No tested functions discovered for $package" >&2; exit 1; }

thunk=$work/thunk
if [[ -e $thunk ]]; then cmake -E remove_directory "$thunk"; fi
manifest_args=()
if [[ -f $port_dir/lorelei/Manifest_guest.cpp ]]; then manifest_args+=(--manifest-guest "$port_dir/lorelei/Manifest_guest.cpp"); fi
if [[ $package == sdl2-ttf || $package == libyaml ]]; then
    # These installed suites only exercise callbacks created inside the host
    # library. Rewriting fields in their public context structs would mistake
    # host callbacks for guest callbacks.
    manifest_args+=(--no-callback-replace)
fi
include_args=(-I"$host_prefix/include")
include_args+=(-I"$port_dir/lorelei")
if [[ -d $native_suite/include ]]; then include_args+=(-I"$native_suite/include"); fi
if [[ $package == qrencode ]]; then include_args+=(-DWITH_TESTS); fi
if [[ $package == sdl2-ttf ]]; then include_args+=(-I"$host_prefix/include/SDL2"); fi
run_logged "$run_dir/logs/preparation/thunk.log" "$devkit/bin/LoreMakeThunk.py" --name "$thunk_name" --out "$thunk" \
    --lib "$host_library" --symbols "$run_dir/generated/Symbols.conf" --desc "$port_dir/lorelei/Desc.h" \
    "${manifest_args[@]}" --devkit "$devkit" --keep-intermediates -- "${include_args[@]}"
readelf -h "$host_library" >"$run_dir/generated/host-elf.txt"
readelf -d "$host_library" >"$run_dir/generated/host-dynamic.txt"
cp "$thunk/.gen/$thunk_name/ThunkStat.json" "$run_dir/generated/ThunkStat.json"

# Interpose the shared allocator shim in the guest. Several upstream suites
# release buffers allocated by the host library with plain free(), so both
# sides must use one heap for those ownership-transferring APIs.
libc_shim=$work/libc-shim
host_libc=$(cc -print-file-name=libc.so.6)
if [[ -e $libc_shim ]]; then cmake -E remove_directory "$libc_shim"; fi
run_logged "$run_dir/logs/preparation/thunk-libc-shim.log" \
    "$devkit/bin/LoreMakeThunk.py" --name c-shim --out "$libc_shim" \
    --lib "$host_libc" --soname libc-shim.so \
    --symbols "$common_dir/libc-shim/Symbols.conf" \
    --desc "$common_dir/libc-shim/Desc.h" \
    --manifest-host "$common_dir/libc-shim/Manifest_host.cpp" \
    --manifest-guest "$common_dir/libc-shim/Manifest_guest.cpp" \
    --devkit "$devkit" --keep-intermediates -- \
    -D_GNU_SOURCE -I"$common_dir/include"
cmake -E create_symlink "$host_libc" "$libc_shim/libc-shim.so"

# SDL2_ttf additionally preserves its zero-hit HLR audit and prepares the SDL2
# dependency thunk before either install-only or test mode returns.
if [[ $package == sdl2-ttf ]]; then
    mkdir -p "$run_dir/generated/targets/SDL2_ttf" "$run_dir/generated/dependencies/SDL2"
    cp -a "$host_prefix/share/sdl2-ttf/hlr-audit/." "$run_dir/generated/targets/SDL2_ttf/"
    cp -a "$host_prefix/share/sdl2/hlr-audit/." "$run_dir/generated/dependencies/SDL2/"
    sdl_port=$overlay/ports/sdl2
    sdl_library=$(find "$host_prefix/lib" -maxdepth 1 -type f -name 'libSDL2-2.0.so.*' | head -1)
    sdl_thunk=$work/sdl-thunk
    if [[ -e $sdl_thunk ]]; then cmake -E remove_directory "$sdl_thunk"; fi
    run_logged "$run_dir/logs/preparation/sdl-thunk.log" "$devkit/bin/LoreMakeThunk.py" --name SDL2 --out "$sdl_thunk" \
        --lib "$sdl_library" --symbols "$sdl_port/lorelei/Symbols.conf" --desc "$sdl_port/lorelei/Desc.h" \
        --manifest-host "$sdl_port/lorelei/Manifest_host.cpp" --manifest-guest "$sdl_port/lorelei/Manifest_guest.cpp" \
        --gtl-alias libSDL2-2.0.so --gtl-alias libSDL2-2.0.so.0 --htl-alias libSDL2-2.0_HTL.so \
        --gtl-arg=-ldl --no-callback-replace --devkit "$devkit" --keep-intermediates -- \
        -I"$host_prefix/include" -I"$host_prefix/include/SDL2" -I"$repo_root/evaluations/common/include"
fi

if $install_only; then
    python3 - "$run_dir/summary.json" "$package" "$host_library" "$thunk" <<'PY'
import json, pathlib, sys
output, package, library, thunk = sys.argv[1:]
mechanism = "TLC + zero-hit HLR audit" if package == "sdl2-ttf" else "TLC Only"
data = {"schema_version": 2, "package": package, "mechanism": mechanism, "status": "installed", "mode": "install-only", "tests_run": False, "host_library": library, "thunk": thunk}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    echo "Installation evidence: $run_dir"
    exit 0
fi

if [[ $package == sdl2-ttf ]]; then
    font=$native_suite/data/DejaVuSans.ttf
    expected_font_sha=bac9c62c06be700ce8067b8b5ed3263329ac84b3bd98e8daeffe46d13a00c6ff338fb5705f447529bf3897ca2e26ec10a1f329ecf30bf02f1473cc8d7e991818
    [[ -f $font ]] || { echo "Pinned DejaVuSans.ttf not found: $font" >&2; exit 2; }
    [[ $(sha512sum "$font" | cut -d' ' -f1) == "$expected_font_sha" ]] || { echo "Font checksum mismatch" >&2; exit 2; }
    set +e
    LD_LIBRARY_PATH="$native_prefix/lib" "$native_suite/bin/lorelei-sdl2-ttf-test" "$font" 2>&1 | tee "$run_dir/logs/native/upstream.log"
    native_status=${PIPESTATUS[0]}
    env LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
        LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
        LD_LIBRARY_PATH="$devkit/lib:$host_prefix/lib:$thunk:$sdl_thunk:$libc_shim" "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
        -E "LORELEI_GUEST_EXTENSIONS=$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
        -E "LD_PRELOAD=$libc_shim/x86_64/libc-shim.so" \
        -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$thunk/x86_64:$sdl_thunk/x86_64:$libc_shim/x86_64" \
        "$guest_suite/bin/lorelei-sdl2-ttf-test" "$font" 2>&1 | tee "$run_dir/logs/hecate/upstream.log"
    hecate_status=${PIPESTATUS[0]}
    set -e
    printf '%s\n' "$native_status" >"$run_dir/logs/native/exit-status.txt"
    printf '%s\n' "$hecate_status" >"$run_dir/logs/hecate/exit-status.txt"
    python3 "$recipe_dir/tools/summarize.py" --run-dir "$run_dir"
    echo "Evidence: $run_dir"
    exit 0
fi

run_one() {
    local lane=$1 cwd=$2 binary=$3
    shift 3
    if [[ $lane == native ]]; then
        (cd "$cwd" && env LD_LIBRARY_PATH="$native_prefix/lib:$native_suite/lib" "$binary" "$@")
    else
        (cd "$cwd" && env LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
            LD_LIBRARY_PATH="$devkit/lib:$host_prefix/lib:$thunk:$libc_shim" \
            "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD -E LD_BIND_NOW=1 \
            -E "LD_PRELOAD=$libc_shim/x86_64/libc-shim.so" \
            -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$thunk/x86_64:$guest_suite/lib:$libc_shim/x86_64" "$binary" "$@")
    fi
}

run_stemmer_suite() {
    local lane=$1 suite=$2 output=$3 binary=$suite/bin/stemwords
    local raw=$work/stemmer-$lane.raw normalized=$work/stemmer-$lane.txt
    local -a utf8=(arabic armenian basque catalan czech danish dutch dutch_porter english esperanto estonian finnish french german greek hindi hungarian indonesian irish italian lithuanian nepali norwegian persian polish porter portuguese romanian russian serbian sesotho spanish swedish tamil turkish yiddish)
    local -a latin1=(basque catalan danish dutch dutch_porter english finnish french german indonesian irish italian norwegian porter portuguese spanish swedish)
    local -a latin2=(czech hungarian polish)
    local -a koi8=(russian)
    : >"$output"
    stem_check() {
        local encoding=$1 algorithm=$2 data=$suite/data/$algorithm input=$work/stem-input expected=$work/stem-expected
        if [[ -f $data/voc.txt.gz ]]; then gzip -dc "$data/voc.txt.gz" >"$input"; else cp "$data/voc.txt" "$input"; fi
        if [[ -f $data/output.txt.gz ]]; then gzip -dc "$data/output.txt.gz" >"$expected"; else cp "$data/output.txt" "$expected"; fi
        if [[ $encoding != UTF_8 ]]; then iconv -f UTF-8 -t "${encoding//_/-}" "$input" >"$work/stem-encoded-input"; input=$work/stem-encoded-input; fi
        run_one "$lane" "$suite" "$binary" -c "$encoding" -l "$algorithm" -i "$input" >"$raw"
        if [[ $encoding != UTF_8 ]]; then iconv -f "${encoding//_/-}" -t UTF-8 "$raw" >"$normalized"; else cp "$raw" "$normalized"; fi
        cmp "$expected" "$normalized"
        echo "PASS $encoding $algorithm" >>"$output"
    }
    local algorithm
    for algorithm in "${utf8[@]}"; do stem_check UTF_8 "$algorithm"; done
    for algorithm in "${latin1[@]}"; do stem_check ISO_8859_1 "$algorithm"; done
    for algorithm in "${latin2[@]}"; do stem_check ISO_8859_2 "$algorithm"; done
    for algorithm in "${koi8[@]}"; do stem_check KOI8_R "$algorithm"; done
}

run_suite() {
    local lane=$1 suite=$2 output=$3 binary name
    : >"$output"
    case $package in
        libstemmer)
            run_stemmer_suite "$lane" "$suite" "$output"
            ;;
        libunibreak)
            for name in line word grapheme; do
                echo "RUN $name" >>"$output"
                run_one "$lane" "$suite/data" "$suite/bin/tests" "$name" >>"$output" 2>&1
                echo "PASS $name" >>"$output"
            done
            ;;
        libthai)
            for name in test_thctype test_thcell test_thinp test_thrend test_thstr test_thwchar; do
                echo "RUN $name" >>"$output"
                run_one "$lane" "$suite" "$suite/bin/$name" >>"$output" 2>&1
                echo "PASS $name" >>"$output"
            done
            echo "RUN thsort" >>"$output"
            run_one "$lane" "$suite" "$suite/bin/thsort" "$suite/data/sorttest.txt" "$work/$lane-sort.txt" >>"$output" 2>&1
            cmp "$suite/data/sorted.txt" "$work/$lane-sort.txt"
            echo "PASS thsort" >>"$output"
            for name in test_thbrk test_thwbrk; do
                echo "RUN $name" >>"$output"
                LIBTHAI_DICTDIR="$native_prefix/share/libthai/libthai" \
                    run_one "$lane" "$suite" "$suite/bin/$name" >>"$output" 2>&1
                echo "PASS $name" >>"$output"
            done
            ;;
        utf8proc)
            for name in case custom iterate misc printproperty valid maxdecomposition charwidth graphemetest normtest; do
                args=()
                [[ $name == graphemetest ]] && args=("$suite/data/GraphemeBreakTest.txt")
                [[ $name == normtest ]] && args=("$suite/data/NormalizationTest.txt")
                echo "RUN $name" >>"$output"
                run_one "$lane" "$suite" "$suite/bin/$name" "${args[@]}" >>"$output" 2>&1
                echo "PASS $name" >>"$output"
            done
            ;;
        *)
            for name in "${guest_tests[@]}"; do
                if [[ " ${excluded_tests[*]} " == *" $name "* ]]; then continue; fi
                echo "RUN $name" >>"$output"
                run_one "$lane" "$suite" "$suite/bin/$name" >>"$output" 2>&1
                echo "PASS $name" >>"$output"
            done
            ;;
    esac
}

run_suite native "$native_suite" "$run_dir/logs/native/upstream.log"
run_suite hecate "$guest_suite" "$run_dir/logs/hecate/upstream.log"
case $package in
    libstemmer) test_count=57 ;;
    libunibreak) test_count=3 ;;
    qrencode) test_count=12 ;;
    *) test_count=$expected_tests ;;
esac
excluded_csv=$(IFS=,; echo "${excluded_tests[*]}")
python3 - "$run_dir/summary.json" "$package" "$test_count" "$expected_tests" "$excluded_csv" <<'PY'
import json, pathlib, sys
output, package, tests, installed, excluded = sys.argv[1:]
data = {"schema_version": 2, "package": package, "mechanism": "TLC Only", "suite": "vcpkg-installed upstream suite", "status": "pass", "tests": int(tests), "installed_test_binaries": int(installed), "excluded_tests": excluded.split(",") if excluded else [], "tests_run": True, "installed_by_vcpkg": True, "native": {"exit_status": 0, "tests_passed": int(tests)}, "hecate": {"exit_status": 0, "tests_passed": int(tests)}, "output_match": None}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
printf 'Native: %s/%s upstream tests passed\n' "$test_count" "$test_count"
printf 'Hecate: %s/%s upstream tests passed\n' "$test_count" "$test_count"
echo "Evidence: $run_dir"
