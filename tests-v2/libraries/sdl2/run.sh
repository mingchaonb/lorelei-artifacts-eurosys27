#!/usr/bin/env bash
set -euo pipefail

# Derive every repository path from this script. The evaluator supplies only the
# installed Lorelei devkit. QEMU may be overridden through QEMU while developing
# against a devkit that does not yet bundle the patched emulator.
recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
common_dir=$repo_root/tests-v2/common
overlay_dir=$repo_root/vcpkg-overlay
sdl_port=$overlay_dir/ports/sdl2
triplet_native=arm64-linux-ae
triplet_guest=x64-linux-ae

# Keep the public interface deliberately small. All test policy is versioned in
# this recipe instead of being selected through evaluator-only command options.
if [[ $# != 1 || $1 == -h || $1 == --help ]]; then
    echo "Usage: $0 /path/to/lorelei-devkit" >&2
    echo "Set QEMU=/path/to/qemu-x86_64 only for a development devkit." >&2
    exit 2
fi
devkit=$(realpath "$1")
qemu=$(realpath -m "${QEMU:-$devkit/bin/qemu-x86_64}")
work_dir=$repo_root/.work/tests-v2/sdl2
results_root=$recipe_dir/results
run_id=$(date -u +%Y%m%dT%H%M%SZ)
jobs=$(nproc)
vcpkg=$repo_root/vcpkg/vcpkg

# Fail before creating evidence if the repository-local package manager, devkit,
# cross compiler, thread hook, sysroot, or patched QEMU is unavailable.
[[ -x $vcpkg ]] || { echo "Bootstrap the repository-local vcpkg checkout with ./vcpkg/bootstrap-vcpkg.sh -disableMetrics" >&2; exit 2; }
for path in bin/LoreMakeThunk.py bin/x86_64-linux-gnu-clang lib/libLoreQEMUThreadHook.so x86_64/sysroot; do
    [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
done
[[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }

# Evidence is append-only. Build products live under the marked .work directory
# and may be replaced. The marker prevents an accidental recursive deletion of a
# user-created directory if the configured path is ever changed.
run_dir=$results_root/$run_id
[[ ! -e $run_dir ]] || { echo "Evidence already exists: $run_dir" >&2; exit 2; }
if [[ -e $work_dir && ! -f $work_dir/.lorelei-tests-v2-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
if [[ -e $work_dir ]]; then cmake -E remove_directory "$work_dir"; fi
mkdir -p "$work_dir" "$run_dir"/{generated,logs/build,logs/native,logs/tlc,logs/hlr}
touch "$work_dir/.lorelei-tests-v2-workspace"

# Mirror the high-level command trace to the terminal and commands.log. Detailed
# stdout and stderr for each build or test remain in their per-stage raw log.
exec > >(tee "$run_dir/commands.log") 2>&1

# run_logged is for commands that must succeed. record_status is for test cases,
# where a nonzero exit must be recorded and classified rather than aborting the
# complete run immediately.
stage() { printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$1"; }
run_logged() { local log=$1; shift; printf '  $'; printf ' %q' "$@"; printf '\n'; "$@" >"$log" 2>&1; }
record_status() {
    local status_file=$1 name=$2 log=$3
    shift 3
    local status
    set +e
    "$@" >"$log" 2>&1
    status=$?
    set -e
    printf '%s\t%s\n' "$name" "$status" >>"$status_file"
    printf '  -> %s exit %s\n' "$name" "$status"
}

# Capture enough machine and tool identity to interpret or repeat this run. The
# JSON file is the stable machine-readable identity, while environment.txt keeps
# the unedited diagnostic output.
stage "Record invocation and environment"
printf '%q ' "$0" "$devkit" >"$run_dir/invocation.txt"
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
    sha256sum "$qemu"
} >"$run_dir/environment.txt" 2>&1
python3 - "$run_dir/meta.json" "$run_id" "$devkit" "$vcpkg" "$qemu" <<'PY'
import datetime, json, pathlib, sys
output, run_id, devkit, vcpkg, qemu = sys.argv[1:]
data = {
    "schema_version": 2, "experiment_id": run_id, "package": "sdl2", "release": "2.28.5",
    "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "lanes": ["native", "tlc", "hlr"],
    "devkit": str(pathlib.Path(devkit).resolve()), "vcpkg": str(pathlib.Path(vcpkg).resolve()),
    "qemu": str(pathlib.Path(qemu).resolve()), "audio_driver": "dummy", "video_driver": "dummy",
}
pathlib.Path(output).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY

# vcpkg uses the devkit environment in the x86-64 triplet and in the HLR feature.
# Each lane receives a separate install and package root so feature variants with
# the same SDL port name cannot overwrite one another.
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$jobs
install_lane() {
    local name=$1 triplet=$2 package=sdl2
    if [[ $name == native || $name == guest ]]; then package='sdl2[tests]'; fi
    if [[ $name == hlr ]]; then package='sdl2[hlr]'; fi
    run_logged "$run_dir/logs/build/vcpkg-$name.log" "$vcpkg" install "$package:$triplet" \
        --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" \
        --x-install-root="$work_dir/installed/$name" \
        --x-buildtrees-root="$work_dir/vcpkg/$name/buildtrees" \
        --x-packages-root="$work_dir/vcpkg/$name/packages" \
        --downloads-root="$work_dir/vcpkg/downloads" --triplet="$triplet"
}

# Build four packages from one overlay port. Native and guest contain identical
# upstream tests for different architectures. TLC contains pristine host SDL.
# HLR contains the rewritten host SDL produced by the port's hlr feature.
stage "Build pinned SDL packages through the repository overlay"
install_lane native "$triplet_native"
install_lane guest "$triplet_guest"
install_lane tlc "$triplet_native"
install_lane hlr "$triplet_native"

native_prefix=$work_dir/installed/native/$triplet_native
guest_prefix=$work_dir/installed/guest/$triplet_guest
native_tests=$native_prefix/libexec/installed-tests/SDL2
guest_tests=$guest_prefix/libexec/installed-tests/SDL2

# Preserve the exact reviewed API surface beside the run evidence. This is the
# symbol list used for both mechanisms, so API selection cannot bias the result.
cp "$sdl_port/lorelei/Symbols.conf" "$run_dir/generated/Symbols.conf"

# Generate an SDL thunk for one host package. Pure TLC uses its normal callback
# replacement. HLR passes --no-callback-replace so callback success is attributable
# to source rewriting and the HLR extensions rather than TLC-generated wrappers.
make_sdl_thunk() {
    local mode=$1 prefix=$2 output=$3 host_library callback_option=()
    host_library=$(find "$prefix/lib" -maxdepth 1 -type f -name 'libSDL2-2.0.so.*' | head -1)
    if [[ $mode == hlr ]]; then callback_option=(--no-callback-replace); fi
    "$devkit/bin/LoreMakeThunk.py" --name SDL2 --out "$output" --lib "$host_library" \
        --symbols "$sdl_port/lorelei/Symbols.conf" --desc "$sdl_port/lorelei/Desc.h" \
        --manifest-host "$sdl_port/lorelei/Manifest_host.cpp" --manifest-guest "$sdl_port/lorelei/Manifest_guest.cpp" \
        --gtl-alias libSDL2-2.0.so --gtl-alias libSDL2-2.0.so.0 --htl-alias libSDL2-2.0_HTL.so \
        --gtl-arg=-ldl "${callback_option[@]}" --devkit "$devkit" --keep-intermediates -- \
        -I"$prefix/include" -I"$prefix/include/SDL2" -I"$common_dir/include"
}

# SDL and its tests cross FILE, printf, and scanf boundaries that host libc cannot
# consume directly from guest objects. Generate the shared libc shim once and use
# it in both transformed lanes.
stage "Generate the shared libc shim"
libc_shim=$work_dir/thunks/libc-shim
host_libc=$(cc -print-file-name=libc.so.6)
run_logged "$run_dir/logs/build/thunk-libc-shim.log" "$devkit/bin/LoreMakeThunk.py" \
    --name c-shim --out "$libc_shim" --lib "$host_libc" --soname libc-shim.so \
    --symbols "$common_dir/libc-shim/Symbols.conf" --desc "$common_dir/libc-shim/Desc.h" \
    --manifest-host "$common_dir/libc-shim/Manifest_host.cpp" --manifest-guest "$common_dir/libc-shim/Manifest_guest.cpp" \
    --devkit "$devkit" --keep-intermediates -- -D_GNU_SOURCE -I"$common_dir/include"
cmake -E create_symlink "$host_libc" "$libc_shim/libc-shim.so"

# Build independent thunk trees from the pristine TLC host package and rewritten
# HLR host package. The guest ABI and selected symbols remain identical.
active_lanes=(tlc hlr)
for mode in "${active_lanes[@]}"; do
    stage "Generate $mode SDL thunk"
    run_logged "$run_dir/logs/build/thunk-$mode.log" make_sdl_thunk "$mode" \
        "$work_dir/installed/$mode/$triplet_native" "$work_dir/thunks/$mode"
done

# Compile the focused callback and function-pointer tests outside the upstream
# suite. The guest executables link one thunk ABI and can run against either lane
# because both generated thunks expose the same SDL sonames.
stage "Build the directed callback and FDG tests"
run_logged "$run_dir/logs/build/directed-native-callbacks.log" cc \
    -I"$native_prefix/include/SDL2" "$recipe_dir/tests/TestCallbacks.c" \
    -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -lSDL2 -pthread -lm \
    -o "$native_tests/test-callbacks-ae"
run_logged "$run_dir/logs/build/directed-native-fdg.log" cc \
    -I"$native_prefix/include/SDL2" "$recipe_dir/tests/TestFDG.c" \
    -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -lSDL2 -pthread -lm \
    -o "$native_tests/test-fdg-ae"
link_thunk=$work_dir/thunks/${active_lanes[0]}
for source in TestCallbacks.c TestFDG.c; do
    output=${source%.c}
    output=${output/TestCallbacks/test-callbacks-ae}
    output=${output/TestFDG/test-fdg-ae}
    run_logged "$run_dir/logs/build/directed-guest-$output.log" "$devkit/bin/x86_64-linux-gnu-clang" \
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

# A guest run loads the selected host SDL and generated thunk into patched QEMU.
# Both lanes preload the thread hook for callbacks on host-created threads. Only
# HLR loads the host and guest HLR extensions. The guest libc shim is preloaded
# before the SDL test executable starts.
run_guest() {
    local mode=$1 name=$2 seconds=$3
    shift 3
    local thunk=$work_dir/thunks/$mode host_prefix=$work_dir/installed/$mode/$triplet_native
    local host_extensions= guest_extensions=
    if [[ $mode == hlr ]]; then
        host_extensions=$devkit/lib/libLoreHostHLRExtension.so
        guest_extensions=$devkit/x86_64/lib/libLoreGuestHLRExtension.so
    fi
    record_status "$run_dir/logs/$mode/status.tsv" "$name" "$run_dir/logs/$mode/$name.log" timeout "${seconds}s" env \
        SDL_AUDIODRIVER=dummy SDL_VIDEODRIVER=dummy LORELEI_HOST_EXTENSIONS="$host_extensions" \
        LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
        LD_LIBRARY_PATH="$devkit/lib:$thunk:$host_prefix/lib:$libc_shim" "$qemu" -L "$devkit/x86_64/sysroot" \
        -U LD_PRELOAD -E LD_BIND_NOW=1 -E SDL_AUDIODRIVER=dummy -E SDL_VIDEODRIVER=dummy \
        -E LORELEI_GUEST_EXTENSIONS="$guest_extensions" -E LD_PRELOAD="$libc_shim/x86_64/libc-shim.so" \
        -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$thunk/x86_64:$libc_shim/x86_64" "$guest_tests/$name" "$@"
}

# Run one fixed-seed automation iteration plus the selected deterministic upstream
# programs and the two directed boundary tests. Lock and atomic stress programs do
# not appear in standalone-tests.tsv because they are outside the stated scope.
for mode in "${active_lanes[@]}"; do : >"$run_dir/logs/$mode/status.tsv"; done
stage "Run the native reference lane"
run_native testautomation 600 --iterations 1 --seed AE2027SDL2DUMMY1
while IFS=$'\t' read -r name seconds arguments; do
    [[ -z $name || $name == \#* ]] && continue
    args=(); [[ -z ${arguments:-} ]] || read -r -a args <<<"$arguments"
    run_native "$name" "$seconds" "${args[@]}"
done <"$recipe_dir/standalone-tests.tsv"
run_native test-callbacks-ae 60
run_native test-fdg-ae 30

for mode in "${active_lanes[@]}"; do
    stage "Run the $mode lane"
    run_guest "$mode" testautomation 600 --iterations 1 --seed AE2027SDL2DUMMY1
    while IFS=$'\t' read -r name seconds arguments; do
        [[ -z $name || $name == \#* ]] && continue
        args=(); [[ -z ${arguments:-} ]] || read -r -a args <<<"$arguments"
        run_guest "$mode" "$name" "$seconds" "${args[@]}"
    done <"$recipe_dir/standalone-tests.tsv"
    run_guest "$mode" test-callbacks-ae 60
    run_guest "$mode" test-fdg-ae 30
done

# Compare TLC and HLR independently with the native exits and automation summary.
# Native-equivalent failures become baseline skips. Mechanism-only differences
# remain failures in summary.json.
stage "Classify both mechanisms against the native lane"
python3 "$recipe_dir/tools/summarize-v2.py" --run-dir "$run_dir"
echo "Evidence: $run_dir"
