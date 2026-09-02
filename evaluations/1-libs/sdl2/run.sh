#!/usr/bin/env bash
set -euo pipefail

# Derive every repository path from this script. LORELEI_DEVKIT and QEMU may override
# the repository-relative defaults for a development installation.
recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
common_dir=$repo_root/evaluations/common
source "$common_dir/host-architecture.sh"
overlay_dir=$repo_root/vcpkg-overlay
sdl_port=$overlay_dir/ports/sdl2
triplet_native=$AE_HOST_TRIPLET
triplet_guest=x64-linux-ae

# Keep the public interface deliberately small. --reference changes only the
# evidence destination and metadata. --install-only prepares the Hecate library
# and thunks without building or running tests. --verbose streams raw command
# output while preserving the same per-stage log files.
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
        --*)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/$AE_TOOL_TRIPLET/tools/qemu-ae/qemu-x86_64}")
# Keep the documented default stable. Developers may select another disposable
# marked workspace to avoid colliding with a concurrent graphics evaluation.
work_dir=${LORELEI_EVALUATION_WORK_DIR:-$repo_root/.work/evaluations/sdl2}
work_dir=$(realpath -m "$work_dir")
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then
    results_root=$recipe_dir/reference-results
    result_kind=reference
fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
jobs=$(nproc)
vcpkg=$repo_root/vcpkg/vcpkg

# Fail before creating evidence if the repository-local package manager or the
# devkit entries needed by the selected mode are unavailable. Installation does
# not execute guest code, so it does not require QEMU or its thread hook.
[[ -x $vcpkg ]] || { echo "Bootstrap the repository-local vcpkg checkout with ./vcpkg/bootstrap-vcpkg.sh -disableMetrics" >&2; exit 2; }
for path in bin/LoreMakeThunk.py bin/LoreHLR bin/x86_64-linux-gnu-clang x86_64/sysroot; do
    [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
done
if ! $install_only; then
    for path in lib/libLoreQEMUThreadHook.so lib/libLoreHostHLRExtension.so x86_64/lib/libLoreGuestHLRExtension.so; do
        [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
    done
    [[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
fi

# Evidence is append-only. ABI-matching vcpkg installs remain under the marked
# .work directory. The marker guards the small set of regenerated scratch paths.
run_dir=$results_root/$run_id
[[ ! -e $run_dir ]] || { echo "Evidence already exists: $run_dir" >&2; exit 2; }
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
# Preserve ABI-matching vcpkg installs across runs. Reset only generated thunks.
if [[ -e $work_dir/thunks ]]; then cmake -E remove_directory "$work_dir/thunks"; fi
mkdir -p "$work_dir" "$run_dir"/{generated,logs/preparation,logs/native,logs/hecate}
touch "$work_dir/.lorelei-evaluations-workspace"

# Mirror the high-level command trace to the terminal and commands.log. Detailed
# stdout and stderr for each build or test remain in their per-stage raw log.
exec > >(tee "$run_dir/commands.log") 2>&1

# run_logged is for commands that must succeed. record_status is for test cases,
# where a nonzero exit must be recorded and classified rather than aborting the
# complete run immediately.
stage() { printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$1"; }
run_logged() {
    local log=$1 status
    shift
    printf '  $'; printf ' %q' "$@"; printf '\n'
    if ! $verbose; then
        "$@" >"$log" 2>&1
        return
    fi
    set +e
    "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    set -e
    return "$status"
}
record_status() {
    local status_file=$1 name=$2 log=$3
    shift 3
    local status
    set +e
    if $verbose; then
        "$@" 2>&1 | tee "$log"
        status=${PIPESTATUS[0]}
    else
        "$@" >"$log" 2>&1
        status=$?
    fi
    set -e
    printf '%s\t%s\n' "$name" "$status" >>"$status_file"
    printf '  -> %s exit %s\n' "$name" "$status"
}

# Capture enough machine and tool identity to interpret or repeat this run. The
# JSON file is the stable machine-readable identity, while environment.txt keeps
# the unedited diagnostic output.
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
    "$devkit/bin/LoreHLR" --version
    if $install_only; then
        echo "QEMU not required in install-only mode"
    else
        sha256sum "$qemu"
    fi
} >"$run_dir/environment.txt" 2>&1
python3 - "$run_dir/meta.json" "$run_id" "$result_kind" "$devkit" "$vcpkg" "$qemu" "$install_only" <<'PY'
import datetime, json, pathlib, sys
output, run_id, result_kind, devkit, vcpkg, qemu, install_only = sys.argv[1:]
install_only = install_only == "true"
data = {
    "schema_version": 2, "experiment_id": run_id, "package": "sdl2", "release": "2.28.5",
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "mode": "install-only" if install_only else "test",
    "lanes": ["hecate-install"] if install_only else ["native", "hecate"],
    "lane_labels": {"native": "Native", "hecate": "Hecate, TLC + HLR"},
    "result_kind": result_kind,
    "devkit": str(pathlib.Path(devkit).resolve()), "vcpkg": str(pathlib.Path(vcpkg).resolve()),
    "qemu": None if install_only else str(pathlib.Path(qemu).resolve()),
    "audio_driver": "dummy", "video_driver": "dummy",
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

# Measure only the three per-library Lorelei configuration files. Symbols, test
# code, patches, and shared harness code use separate effort metrics and are not
# included in this configuration LOC total.
stage "Measure per-library Lorelei configuration LOC"
run_logged "$run_dir/logs/preparation/configuration-loc.log" \
    python3 "$common_dir/tools/count-configuration-loc.py" \
    --root "$repo_root" \
    --output "$run_dir/generated/configuration-loc.json" \
    "$sdl_port/lorelei/Desc.h" \
    "$sdl_port/lorelei/Manifest_guest.cpp" \
    "$sdl_port/lorelei/Manifest_host.cpp"

# vcpkg uses the devkit environment in the x86-64 triplet and in the HLR feature.
# Each lane receives a separate install and package root so feature variants with
# the same SDL port name cannot overwrite one another.
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$jobs
install_lane() {
    local name=$1 triplet=$2 package=sdl2
    if [[ $name == native || $name == guest ]]; then package='sdl2[tests]'; fi
    if [[ $name == hecate ]]; then package='sdl2[hlr]'; fi
    run_logged "$run_dir/logs/preparation/vcpkg-$name.log" "$vcpkg" install "$package:$triplet" \
        --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" \
        --x-install-root="$work_dir/installed/$name" \
        --x-buildtrees-root="$work_dir/vcpkg/$name/buildtrees" \
        --x-packages-root="$work_dir/vcpkg/$name/packages" \
        --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}

# A test run builds native and guest test packages plus the HLR-rewritten Hecate
# host library. Install-only mode builds only the Hecate package.
stage "Build pinned SDL packages through the repository overlay"
if ! $install_only; then
    install_lane native "$triplet_native"
    install_lane guest "$triplet_guest"
fi
install_lane hecate "$triplet_native"

# Preserve the exact reviewed API surface beside the run evidence.
cp "$sdl_port/lorelei/Symbols.conf" "$run_dir/generated/Symbols.conf"

# Generate the Hecate SDL thunk from the rewritten host package. Hecate still uses
# TLC for thunk generation, but --no-callback-replace makes callback handling come
# from HLR rewriting and extensions rather than TLC-generated callback wrappers.
make_sdl_thunk() {
    local prefix=$1 output=$2 host_library
    host_library=$(find "$prefix/lib" -maxdepth 1 -type f -name 'libSDL2-2.0.so.*' | head -1)
    "$repo_root/evaluations/1-libs/_common/lore-make-thunk.py" "$devkit/bin/LoreMakeThunk.py" --name SDL2 --out "$output" --lib "$host_library" \
        --symbols "$sdl_port/lorelei/Symbols.conf" --desc "$sdl_port/lorelei/Desc.h" \
        --manifest-host "$sdl_port/lorelei/Manifest_host.cpp" --manifest-guest "$sdl_port/lorelei/Manifest_guest.cpp" \
        --gtl-alias libSDL2-2.0.so --gtl-alias libSDL2-2.0.so.0 --htl-alias libSDL2-2.0_HTL.so \
        --gtl-arg=-ldl --no-callback-replace --devkit "$devkit" --keep-intermediates -- \
        -I"$prefix/include" -I"$prefix/include/SDL2" -I"$common_dir/include"
}

# SDL and its tests cross FILE, printf, and scanf boundaries that host libc cannot
# consume directly from guest objects. Generate one shared shim for Hecate.
stage "Generate the shared libc shim"
libc_shim=$work_dir/thunks/libc-shim
host_libc=$(cc -print-file-name=libc.so.6)
run_logged "$run_dir/logs/preparation/thunk-libc-shim.log" "$repo_root/evaluations/1-libs/_common/lore-make-thunk.py" "$devkit/bin/LoreMakeThunk.py" \
    --name c-shim --out "$libc_shim" --lib "$host_libc" --soname libc-shim.so \
    --symbols "$common_dir/libc-shim/Symbols.conf" --desc "$common_dir/libc-shim/Desc.h" \
    --manifest-host "$common_dir/libc-shim/Manifest_host.cpp" --manifest-guest "$common_dir/libc-shim/Manifest_guest.cpp" \
    --devkit "$devkit" --keep-intermediates -- -D_GNU_SOURCE -I"$common_dir/include"
cmake -E create_symlink "$host_libc" "$libc_shim/libc-shim.so"

# Build the one transformed path evaluated for SDL.
stage "Generate the Hecate SDL thunk"
run_logged "$run_dir/logs/preparation/thunk-hecate.log" make_sdl_thunk \
    "$work_dir/installed/hecate/$triplet_native" "$work_dir/thunks/hecate"

# An evaluator may stop after installing the complete Hecate SDL path. Record
# the usable prefixes and make it explicit that no correctness test was run.
if $install_only; then
    stage "Record the installed Hecate library"
    python3 - "$run_dir/summary.json" "$work_dir/installed/hecate/$triplet_native" "$work_dir/thunks/hecate" "$libc_shim" <<'PY'
import json, pathlib, sys
output, host_prefix, sdl_thunk, libc_shim = sys.argv[1:]
data = {
    "schema_version": 2,
    "package": "sdl2",
    "mode": "install-only",
    "status": "installed",
    "tests_run": False,
    "installed": {
        "hecate_host": str(pathlib.Path(host_prefix).resolve()),
        "sdl_thunk": str(pathlib.Path(sdl_thunk).resolve()),
        "libc_shim": str(pathlib.Path(libc_shim).resolve()),
    },
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
    echo "Hecate host library: $work_dir/installed/hecate/$triplet_native"
    echo "SDL thunk: $work_dir/thunks/hecate"
    echo "libc shim: $libc_shim"
    echo "Installation record: $run_dir"
    exit 0
fi

native_prefix=$work_dir/installed/native/$triplet_native
guest_prefix=$work_dir/installed/guest/$triplet_guest
native_tests=$native_prefix/libexec/installed-tests/SDL2
guest_tests=$guest_prefix/libexec/installed-tests/SDL2

# Compile the focused callback and function-pointer tests outside the upstream
# suite. Guest executables link the Hecate thunk ABI.
stage "Build the directed callback and FDG tests"
run_logged "$run_dir/logs/preparation/directed-native-callbacks.log" cc \
    -I"$native_prefix/include/SDL2" "$recipe_dir/tests/TestCallbacks.c" \
    -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -lSDL2 -pthread -lm \
    -o "$native_tests/test-callbacks-ae"
run_logged "$run_dir/logs/preparation/directed-native-fdg.log" cc \
    -I"$native_prefix/include/SDL2" "$recipe_dir/tests/TestFDG.c" \
    -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -lSDL2 -pthread -lm \
    -o "$native_tests/test-fdg-ae"
link_thunk=$work_dir/thunks/hecate
for source in TestCallbacks.c TestFDG.c; do
    output=${source%.c}
    output=${output/TestCallbacks/test-callbacks-ae}
    output=${output/TestFDG/test-fdg-ae}
    run_logged "$run_dir/logs/preparation/directed-guest-$output.log" "$devkit/bin/x86_64-linux-gnu-clang" \
        --sysroot="$devkit/x86_64/sysroot" -I"$guest_prefix/include/SDL2" "$recipe_dir/tests/$source" \
        -L"$link_thunk/x86_64" -Wl,-rpath,"$link_thunk/x86_64" -l:libSDL2.so -pthread -lm \
        -o "$guest_tests/$output"
done

# Native runs provide the classification baseline. Every command uses dummy audio
# and video drivers and writes its exit status plus unedited output to the lane.
native_status=$run_dir/logs/native/status.tsv
: >"$native_status"
run_native() {
    local name=$1 seconds=$2
    shift 2
    record_status "$native_status" "$name" "$run_dir/logs/native/$name.log" timeout "${seconds}s" env \
        SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy LD_LIBRARY_PATH="$native_prefix/lib" "$native_tests/$name" "$@"
}

# A Hecate run loads the HLR-rewritten host SDL and generated thunk into patched
# QEMU. The thread hook supports callbacks on host-created threads. Host and guest
# HLR extensions implement callback and FDG handling.
run_hecate() {
    local name=$1 seconds=$2
    shift 2
    local thunk=$work_dir/thunks/hecate host_prefix=$work_dir/installed/hecate/$triplet_native
    record_status "$run_dir/logs/hecate/status.tsv" "$name" "$run_dir/logs/hecate/$name.log" timeout "${seconds}s" env \
        SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy \
        LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
        LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
        LD_LIBRARY_PATH="$devkit/lib:$thunk:$host_prefix/lib:$libc_shim" "$qemu" -L "$devkit/x86_64/sysroot" \
        -U LD_PRELOAD -E LD_BIND_NOW=1 -E SDL_AUDIODRIVER=dummy -E SDL_VIDEODRIVER=dummy \
        -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
        -E LD_PRELOAD="$libc_shim/x86_64/libc-shim.so" \
        -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$thunk/x86_64:$libc_shim/x86_64" "$guest_tests/$name" "$@"
}

# Run one fixed-seed automation iteration plus the selected deterministic upstream
# programs and the two directed boundary tests. Lock and atomic stress programs do
# not appear in standalone-tests.tsv because they are outside the stated scope.
: >"$run_dir/logs/hecate/status.tsv"
stage "Run the native reference lane"
run_native testautomation 600 --iterations 1 --seed AE2027SDL2DUMMY1
while IFS=$'\t' read -r name seconds arguments; do
    [[ -z $name || $name == \#* ]] && continue
    args=(); [[ -z ${arguments:-} ]] || read -r -a args <<<"$arguments"
    run_native "$name" "$seconds" "${args[@]}"
done <"$recipe_dir/standalone-tests.tsv"
run_native test-callbacks-ae 60
run_native test-fdg-ae 30

stage "Run the Hecate path, TLC + HLR"
run_hecate testautomation 600 --iterations 1 --seed AE2027SDL2DUMMY1
while IFS=$'\t' read -r name seconds arguments; do
    [[ -z $name || $name == \#* ]] && continue
    args=(); [[ -z ${arguments:-} ]] || read -r -a args <<<"$arguments"
    run_hecate "$name" "$seconds" "${args[@]}"
done <"$recipe_dir/standalone-tests.tsv"
run_hecate test-callbacks-ae 60
run_hecate test-fdg-ae 30

# Compare Hecate with the native exits and automation summary.
# Native-equivalent failures become baseline skips. Mechanism-only differences
# remain failures in summary.json.
stage "Classify both mechanisms against the native lane"
python3 "$recipe_dir/tools/summarize.py" --run-dir "$run_dir"
echo "Evidence: $run_dir"
