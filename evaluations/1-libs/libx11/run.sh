#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
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
qemu=$(realpath "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
gui_env=${GUI_ENV:-$HOME/Desktop/spark-gui-env.txt}
run_id=$(date -u +%Y%m%dT%H%M%SZ)
results_root=$recipe_dir/results
result_kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; result_kind=reference; fi
run_dir=$results_root/$run_id
work_dir=$repo_root/.work/evaluations/libx11
vcpkg=$repo_root/vcpkg/vcpkg
overlay=$repo_root/vcpkg-overlay

[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg before running this recipe" >&2; exit 2; }
[[ -x $devkit/bin/LoreMakeThunk.py ]] || { echo "Invalid devkit: $devkit" >&2; exit 2; }
if ! $install_only; then
    [[ -x $qemu && -f $gui_env ]] || { echo "Missing QEMU or GUI environment" >&2; exit 2; }
    [[ -e $devkit/lib/libLoreQEMUThreadHook.so ]] || { echo "Missing Hecate thread hook" >&2; exit 2; }
    nm -D "$qemu" | grep qemu_lorelei_reentry > /dev/null || { echo "QEMU lacks Hecate reentry support" >&2; exit 2; }
fi
if [[ -e $work_dir && ! -f $work_dir/.lorelei-evaluations-workspace ]]; then
    echo "Refusing to replace unmarked work directory: $work_dir" >&2
    exit 2
fi
# Preserve ABI-matching vcpkg installs across runs. Reset only derived test and thunk files.
if [[ -e $work_dir/thunk ]]; then cmake -E remove_directory "$work_dir/thunk"; fi
cmake -E rm -f "$work_dir/test-native" "$work_dir/test-hecate"
mkdir -p "$work_dir" "$run_dir"/{logs/preparation,logs/native,logs/hecate,generated}
touch "$work_dir/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

run_logged() {
    local log=$1 status
    shift
    if ! $verbose; then "$@" >"$log" 2>&1; return; fi
    set +e
    "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    set -e
    return "$status"
}

export LORELEI_DEVKIT=$devkit
common=(--overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets"
    --downloads-root="$repo_root/vcpkg/downloads")
install_lane() {
    local lane=$1 package=$2 triplet=$3
    run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "$package:$triplet" "${common[@]}" \
        --x-install-root="$work_dir/installed/$lane" \
        --x-buildtrees-root="$work_dir/vcpkg/$lane/buildtrees" \
        --x-packages-root="$work_dir/vcpkg/$lane/packages"
}

install_lane native libx11 arm64-linux-ae
install_lane guest libx11 x64-linux-ae
install_lane hecate 'libx11[hlr]' arm64-linux-ae
native=$work_dir/installed/native/arm64-linux-ae
guest=$work_dir/installed/guest/x64-linux-ae
hecate=$work_dir/installed/hecate/arm64-linux-ae
host_library=$(find "$hecate/lib" -maxdepth 1 -type f -name 'libX11.so.*' | head -1)
thunk=$work_dir/thunk
run_logged "$run_dir/logs/preparation/thunk.log" "$devkit/bin/LoreMakeThunk.py" --name X11 --out "$thunk" --lib "$host_library" \
    --symbols "$overlay/ports/libx11/lorelei/Symbols.conf" \
    --desc "$overlay/ports/libx11/lorelei/Desc.h" --no-callback-replace \
    --devkit "$devkit" --keep-intermediates \
    --manifest-host "$overlay/ports/libx11/lorelei/Manifest_host.cpp" \
    --manifest-guest "$overlay/ports/libx11/lorelei/Manifest_guest.cpp" \
    -- -I"$hecate/include"

cp -a "$hecate/share/libx11/hlr-audit/." "$run_dir/generated/"
if $install_only; then
    python3 - "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({"schema_version": 2, "package": "libx11", "status": "installed", "tests_run": False}, indent=2, sort_keys=True) + "\n")
PY
    echo "Installation evidence: $run_dir"
    exit 0
fi

display=$(sed -n 's/^DISPLAY=//p' "$gui_env" | tail -1)
xauthority=$(sed -n 's/^XAUTHORITY=//p' "$gui_env" | tail -1)
[[ -n $display && -n $xauthority ]] || { echo "DISPLAY or XAUTHORITY missing" >&2; exit 2; }

cc -I"$native/include" "$recipe_dir/tests/TestX11.c" -L"$native/lib" -Wl,-rpath,"$native/lib" -lX11 -o "$work_dir/test-native"
"$devkit/bin/x86_64-linux-gnu-clang" --sysroot="$devkit/x86_64/sysroot" \
    -I"$guest/include" "$recipe_dir/tests/TestX11.c" -L"$guest/lib" \
    -Wl,-rpath,"$guest/lib" -lX11 -o "$work_dir/test-hecate"

dpkg-query -W -f='${Package} ${Version}\n' libx11-6 libx11-dev \
    | tee "$run_dir/generated/native-packages.txt"
env DISPLAY="$display" XAUTHORITY="$xauthority" LD_LIBRARY_PATH="$native/lib" \
    "$work_dir/test-native" | tee "$run_dir/logs/native/x11.log"
env LORELEI_HOST_EXTENSIONS="$devkit/lib/libLoreHostHLRExtension.so" \
    DISPLAY="$display" XAUTHORITY="$xauthority" \
    LD_PRELOAD="$devkit/lib/libLoreQEMUThreadHook.so" \
    LD_LIBRARY_PATH="$devkit/lib:$thunk:$hecate/lib" \
    "$qemu" -L "$devkit/x86_64/sysroot" -U LD_PRELOAD \
    -E DISPLAY="$display" -E XAUTHORITY="$xauthority" -E LD_BIND_NOW=1 \
    -E LORELEI_GUEST_EXTENSIONS="$devkit/x86_64/lib/libLoreGuestHLRExtension.so" \
    -E LD_LIBRARY_PATH="$devkit/x86_64/lib:$thunk/x86_64" \
    "$work_dir/test-hecate" | tee "$run_dir/logs/hecate/x11.log"

python3 - "$run_dir/summary.json" "$run_id" "$result_kind" <<'PY'
import json, pathlib, sys
path, run_id, result_kind = sys.argv[1:]
data = {"schema_version": 2, "experiment_id": run_id, "package": "libx11",
        "release": "1.8.7", "result_kind": result_kind, "status": "pass",
        "tests_run": True, "tests": ["native", "hecate"],
        "variadic_apis_exercised": ["XGetIMValues", "XCreateIC", "XGetICValues",
                                      "XVaCreateNestedList"]}
pathlib.Path(path).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
echo "Evidence: $run_dir"
