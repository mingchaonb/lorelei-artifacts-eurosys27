#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
overlay_dir=$repo_root/vcpkg-overlay
port_dir=$overlay_dir/ports/ffmpeg
triplet=arm64-linux-ae
triplet_guest=x64-linux-ae

reference=false
install_only=false
verbose=false
positional=()
while (($#)); do
    case $1 in
        --reference) reference=true ;;
        --install-only) install_only=true ;;
        --verbose) verbose=true ;;
        -h|--help)
            echo "Usage: $0 [--reference] [--install-only] [--verbose]"
            echo "Set QEMU=/path/to/qemu-x86_64 only for a development devkit."
            exit 0
            ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done

devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/../lorelei-ae/build/install}")
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
work_dir=$repo_root/.work/evaluations/ffmpeg
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; result_kind=reference; fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id

# Validate the repository-local package manager and devkit before creating evidence.
[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg before running this recipe" >&2; exit 2; }
for path in bin/LoreMakeThunk.py bin/x86_64-linux-gnu-clang x86_64/sysroot; do
    [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
done
if ! $install_only; then
    for path in lib/libLoreQEMUThreadHook.so lib/libLoreHostHLRExtension.so x86_64/lib/libLoreGuestHLRExtension.so; do
        [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
    done
    [[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
fi

# Preserve vcpkg install state across runs. Only generated thunks and wrappers are reset.
[[ ! -e $run_dir ]] || { echo "Evidence already exists: $run_dir" >&2; exit 2; }
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to use unmarked work directory: $work_dir" >&2
    exit 2
fi
for scratch_path in "$work_dir/thunks" "$work_dir/wrappers"; do
    if [[ -e $scratch_path ]]; then cmake -E remove_directory "$scratch_path"; fi
done
mkdir -p "$work_dir" "$run_dir"/{generated/symbols,logs/preparation,logs/native,logs/hecate}
touch "$work_dir/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

stage() { printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$1"; }
run_logged() {
    local log=$1 status
    shift
    printf '  $'; printf ' %q' "$@"; printf '\n'
    if ! $verbose; then "$@" >"$log" 2>&1; return; fi
    set +e
    "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    set -e
    return "$status"
}
run_recorded() {
    local log=$1 status_file=$2 status
    shift 2
    printf '  $'; printf ' %q' "$@"; printf '\n'
    set +e
    if $verbose; then
        "$@" 2>&1 | tee "$log"
        status=${PIPESTATUS[0]}
    else
        "$@" >"$log" 2>&1
        status=$?
    fi
    set -e
    printf '%s\n' "$status" >"$status_file"
    printf '  -> exit %s\n' "$status"
}

stage "Record invocation and environment"
invocation=(env "LORELEI_DEVKIT=$devkit" "$recipe_dir/run.sh")
if $reference; then invocation+=(--reference); fi
if $install_only; then invocation+=(--install-only); fi
if $verbose; then invocation+=(--verbose); fi
printf '%q ' "${invocation[@]}" >"$run_dir/invocation.txt"
printf '\n' >>"$run_dir/invocation.txt"
{
    date -u --iso-8601=seconds
    uname -a
    cat /etc/os-release
    lscpu
    free -h
    uptime
    "$vcpkg" version
    sha256sum "$port_dir/run-hlr.py" "$port_dir/capture-cc.py"
    sha256sum "$port_dir/patches/static-descriptors.patch" "$port_dir/patches/export-file-context.patch"
    if ! $install_only; then sha256sum "$qemu"; fi
} >"$run_dir/environment.txt" 2>&1
python3 - "$run_dir/meta.json" "$run_id" "$result_kind" "$devkit" "$qemu" "$install_only" <<'PY'
import datetime, json, pathlib, sys
output, run_id, result_kind, devkit, qemu, install_only = sys.argv[1:]
data = {
    "schema_version": 2,
    "experiment_id": run_id,
    "package": "ffmpeg",
    "release": "7.1.5",
    "upstream_commit": "3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587",
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "result_kind": result_kind,
    "mode": "install-only" if install_only == "true" else "test",
    "mechanism": "TLC + HLR",
    "lanes": ["native", "hecate"],
    "devkit": str(pathlib.Path(devkit).resolve()),
    "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve()),
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

stage "Measure repository-owned FFmpeg configuration"
configuration_files=()
for lib in avutil swresample swscale avcodec avformat avfilter avdevice; do
    configuration_files+=("$port_dir/lorelei/$lib/Desc.h")
    configuration_files+=("$port_dir/lorelei/$lib/Symbols.conf")
done
run_logged "$run_dir/logs/preparation/configuration-loc.log" \
    python3 "$repo_root/evaluations/common/tools/count-configuration-loc.py" \
    --root "$repo_root" --output "$run_dir/generated/configuration-loc.json" \
    "${configuration_files[@]}"
{
    git apply --stat "$port_dir/patches/static-descriptors.patch"
    git apply --stat "$port_dir/patches/export-file-context.patch"
} >"$run_dir/generated/post-hlr-patch-stat.txt"

# Install native, guest, and Hecate packages. Guest is preparation for the
# Hecate result lane and is not reported as a third execution result.
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY
VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
    local lane=$1 lane_triplet=$2 package=ffmpeg
    if [[ $lane == hecate ]]; then package='ffmpeg[hlr]'; fi
    run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "$package:$lane_triplet" \
        --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" \
        --x-install-root="$work_dir/installed/$lane" \
        --x-buildtrees-root="$work_dir/vcpkg/$lane/buildtrees" \
        --x-packages-root="$work_dir/vcpkg/$lane/packages" \
        --downloads-root="$repo_root/vcpkg/downloads" --triplet="$lane_triplet"
}

stage "Install native, guest, and Hecate FFmpeg packages"
install_lane native "$triplet"
install_lane guest "$triplet_guest"
install_lane hecate "$triplet"

native_prefix=$work_dir/installed/native/$triplet
guest_prefix=$work_dir/installed/guest/$triplet_guest
hecate_prefix=$work_dir/installed/hecate/$triplet
native_tests=$native_prefix/tools/ffmpeg/upstream-tests
guest_tests=$guest_prefix/tools/ffmpeg/upstream-tests
for path in \
    "$native_prefix/bin/ffmpeg" "$native_prefix/bin/ffprobe" "$native_tests/build" \
    "$guest_prefix/bin/ffmpeg" "$guest_prefix/bin/ffprobe" "$guest_tests/build" \
    "$hecate_prefix/bin/ffmpeg" "$hecate_prefix/bin/ffprobe" "$hecate_prefix/tools/ffmpeg/upstream-tests/build"; do
    [[ -e $path ]] || { echo "Missing installed FFmpeg artifact: $path" >&2; exit 1; }
done

# Find the API surface imported by every installed x86-64 FATE executable.
stage "Discover symbols from installed Hecate tests"
guest_executables=$run_dir/generated/guest-executables.txt
: >"$guest_executables"
while IFS= read -r -d '' executable; do
    if file "$executable" | grep -q 'ELF 64-bit LSB.*x86-64'; then
        printf '%s\n' "$executable" >>"$guest_executables"
    fi
done < <(find "$guest_tests/build" -type f -perm -111 -print0)
sort -u -o "$guest_executables" "$guest_executables"
[[ -s $guest_executables ]] || { echo "No installed x86-64 FFmpeg tests found" >&2; exit 1; }
while IFS= read -r executable; do
    readelf -Ws "$executable"
done <"$guest_executables" | awk '$7 == "UND" { name=$8; sub(/@.*/, "", name); if (name != "") print name }' \
    | sort -u >"$run_dir/generated/guest-undefined.txt"

# Generate one TLC context per libav DSO into a single runtime pack.
stage "Generate seven FFmpeg thunks with callback replacement disabled"
pack=$work_dir/thunks/pack
declare -A sonames=(
    [avutil]=59 [swresample]=5 [swscale]=8 [avcodec]=61
    [avformat]=61 [avfilter]=10 [avdevice]=61
)
for lib in avutil swresample swscale avcodec avformat avfilter avdevice; do
    host_library=$hecate_prefix/lib/lib$lib.so.${sonames[$lib]}
    [[ -e $host_library ]] || { echo "Missing HLR host DSO: $host_library" >&2; exit 1; }
    symbol_dir=$run_dir/generated/symbols/$lib
    mkdir -p "$symbol_dir"
    nm -D --defined-only --format=posix "$host_library" \
        | awk '$2 == "T" || $2 == "W" { name=$1; sub(/@.*/, "", name); print name }' \
        | sort -u >"$symbol_dir/host-functions.txt"
    comm -12 "$run_dir/generated/guest-undefined.txt" "$symbol_dir/host-functions.txt" \
        >"$symbol_dir/functions.txt"
    { printf '[Function]\n'; cat "$symbol_dir/functions.txt"; } >"$symbol_dir/Symbols.conf"
    [[ -s $symbol_dir/functions.txt ]] || { echo "No imported functions found for lib$lib" >&2; exit 1; }
    run_logged "$run_dir/logs/preparation/thunk-$lib.log" "$devkit/bin/LoreMakeThunk.py" \
        --name "$lib" --out "$pack" --lib "$host_library" \
        --symbols "$symbol_dir/Symbols.conf" --desc "$port_dir/lorelei/$lib/Desc.h" \
        --gtl-alias "lib$lib.so" --gtl-alias "lib$lib.so.${sonames[$lib]}" \
        --gtl-arg="-Wl,--version-script=$guest_tests/build/lib$lib/lib$lib.ver" \
        --no-callback-replace --devkit "$devkit" --keep-intermediates -- \
        -I"$guest_tests/source" -I"$guest_tests/build" -I"$guest_prefix/include" \
        -D__STDC_CONSTANT_MACROS
    cp "$pack/.gen/$lib/ThunkStat.json" "$symbol_dir/ThunkStat.json"
done
cp -a "$hecate_prefix/share/ffmpeg/hlr-audit" "$run_dir/generated/hlr-audit"

if $install_only; then
    python3 - "$run_dir/summary.json" "$native_prefix" "$guest_prefix" "$hecate_prefix" "$pack" <<'PY'
import json, pathlib, sys
output, native, guest, hecate, pack = sys.argv[1:]
data = {
    "schema_version": 2,
    "package": "ffmpeg",
    "status": "installed",
    "mode": "install-only",
    "tests_run": False,
    "installed": {"native": native, "guest": guest, "hecate": hecate, "thunk_pack": pack},
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    echo "Native package: $native_prefix"
    echo "Guest package: $guest_prefix"
    echo "Hecate package: $hecate_prefix"
    echo "FFmpeg thunk pack: $pack"
    echo "Installation record: $run_dir"
    exit 0
fi

# Confirm that both installed package copies register the same configured suite.
stage "Compare installed FATE manifests"
(cd "$native_tests/build" && make -s fate-list) \
    | awk '{ for (i=1; i<=NF; i++) if ($i ~ /^fate-/) print $i }' \
    | sort -u >"$run_dir/generated/fate-native.txt"
(cd "$guest_tests/build" && make -s fate-list) \
    | awk '{ for (i=1; i<=NF; i++) if ($i ~ /^fate-/) print $i }' \
    | sort -u >"$run_dir/generated/fate-hecate.txt"
cmp "$run_dir/generated/fate-native.txt" "$run_dir/generated/fate-hecate.txt" \
    >"$run_dir/logs/preparation/fate-manifest.diff" || true

# Use small wrappers so FFmpeg's make-based FATE runner sees a single TARGET_EXEC.
mkdir -p "$work_dir/wrappers"
native_exec=$work_dir/wrappers/native-exec
hecate_exec=$work_dir/wrappers/hecate-exec
printf '#!/usr/bin/env bash\nexec env LD_LIBRARY_PATH=%q "$@"\n' "$native_prefix/lib" >"$native_exec"
printf '#!/usr/bin/env bash\nexec env LORELEI_HOST_EXTENSIONS=%q LD_PRELOAD=%q LD_LIBRARY_PATH=%q %q -L %q -U LD_PRELOAD -E LD_BIND_NOW=1 -E LORELEI_GUEST_EXTENSIONS=%q -E LD_LIBRARY_PATH=%q "$@"\n' \
    "$devkit/lib/libLoreHostHLRExtension.so" "$devkit/lib/libLoreQEMUThreadHook.so" \
    "$devkit/lib:$pack:$hecate_prefix/lib" "$qemu" "$devkit/x86_64/sysroot" \
    "$devkit/x86_64/lib/libLoreGuestHLRExtension.so" "$devkit/x86_64/lib:$pack/x86_64" \
    >"$hecate_exec"
chmod +x "$native_exec" "$hecate_exec"

# Run every registered test from the two installed package trees.
stage "Run the complete configured native FATE suite"
run_recorded "$run_dir/logs/native/fate.log" "$run_dir/logs/native/fate-exit-status.txt" \
    make -C "$native_tests/build" -k -j"$(nproc)" fate fate-hw TARGET_EXEC="$native_exec"
stage "Run the complete configured Hecate FATE suite"
run_recorded "$run_dir/logs/hecate/fate.log" "$run_dir/logs/hecate/fate-exit-status.txt" \
    make -C "$guest_tests/build" -k -j"$(nproc)" fate fate-hw TARGET_EXEC="$hecate_exec"

# Repeat the callback regression that exposed the missing threadmessage CCG.
for lane in native hecate; do
    if [[ $lane == native ]]; then test_root=$native_tests; target_exec=$native_exec; else test_root=$guest_tests; target_exec=$hecate_exec; fi
    status_file=$run_dir/logs/$lane/api-threadmessage-status.tsv
    : >"$status_file"
    stage "Repeat api-threadmessage five times in the $lane lane"
    for repetition in 1 2 3 4 5; do
        log=$run_dir/logs/$lane/api-threadmessage-$repetition.log
        set +e
        if $verbose; then
            make -C "$test_root/build" -j1 fate-api-threadmessage TARGET_EXEC="$target_exec" 2>&1 | tee "$log"
            status=${PIPESTATUS[0]}
        else
            make -C "$test_root/build" -j1 fate-api-threadmessage TARGET_EXEC="$target_exec" >"$log" 2>&1
            status=$?
        fi
        set -e
        printf '%s\t%s\n' "$repetition" "$status" >>"$status_file"
        printf '  -> repetition %s exit %s\n' "$repetition" "$status"
    done
done

stage "Classify Hecate against the native baseline"
python3 "$recipe_dir/tools/summarize.py" --run-dir "$run_dir"
echo "Evidence: $run_dir"
