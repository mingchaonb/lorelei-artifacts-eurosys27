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
vcpkg=$repo_root/vcpkg/vcpkg
[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg first" >&2; exit 2; }
[[ -x $devkit/bin/x86_64-linux-gnu-clang ]] || { echo "Invalid devkit: $devkit" >&2; exit 2; }
kind=results
$reference && kind=reference-results
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$recipe_dir/$kind/$run_id
work=$repo_root/.work/evaluations/murmurhash
[[ ! -e $run_dir ]] || { echo "Evidence exists: $run_dir" >&2; exit 2; }
mkdir -p "$run_dir/logs/preparation" "$run_dir/logs/native" "$run_dir/logs/hecate" "$run_dir/generated" "$work"
exec > >(tee "$run_dir/commands.log") 2>&1
export LORELEI_DEVKIT=$devkit
install_lane() {
    local lane=$1 triplet=$2
    "$vcpkg" install "murmurhash:$triplet" --overlay-ports="$overlay/ports" --overlay-triplets="$overlay/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads" >"$run_dir/logs/preparation/vcpkg-$lane.log" 2>&1
}
install_lane native arm64-linux-ae
install_lane guest x64-linux-ae
find "$work/installed/native/arm64-linux-ae/lib" "$work/installed/guest/x64-linux-ae/lib" -maxdepth 1 -type f -name '*.so*' -print -exec file {} \; -exec readelf -d {} \; -exec readelf -Ws {} \; >"$run_dir/generated/shared-library-audit.txt"
python3 - "$run_dir/meta.json" "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
meta = {"schema_version": 2, "package": "murmurhash", "release": "0.2.0", "mechanism": "TLC Only", "workload": "the 19 upstream known-answer cases"}
pathlib.Path(sys.argv[1]).write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n")
summary = {"schema_version": 2, "package": "murmurhash", "status": "installed", "tests_run": False}
pathlib.Path(sys.argv[2]).write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY
native=$work/installed/native/arm64-linux-ae
guest=$work/installed/guest/x64-linux-ae
mkdir -p "$work/thunks"
native_test=$native/tools/murmurhash/upstream-tests/test
guest_test=$guest/tools/murmurhash/upstream-tests/test
[[ -x $native_test && -x $guest_test ]] || { echo "Installed upstream tests are missing" >&2; exit 2; }
host_library=$(find "$native/lib" -maxdepth 1 -type f -name 'libmurmurhash.so*' | head -1)
"$repo_root/evaluations/1-libs/_common/lore-make-thunk.py" "$devkit/bin/LoreMakeThunk.py" --name murmurhash --out "$work/thunks/murmurhash" --lib "$host_library" --symbols "$recipe_dir/lorelei/Symbols.conf" --desc "$recipe_dir/lorelei/Desc.h" --devkit "$devkit" --keep-intermediates -- -I"$native/include" >"$run_dir/logs/preparation/thunk.log" 2>&1
readelf -d "$guest_test" >"$run_dir/generated/guest-test-dynamic.txt"
grep -q 'libmurmurhash.so' "$run_dir/generated/guest-test-dynamic.txt"
cp "$work/thunks/murmurhash/.gen/murmurhash/ThunkStat.json" "$run_dir/generated/TLC-ThunkStat.json"
if $install_only; then
    echo "Installed packages and generated TLC artifacts"
    echo "Evidence: $run_dir"
    exit 0
fi
qemu=$(realpath -m "${QEMU:-$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64}")
[[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
LD_LIBRARY_PATH="$native/lib" "$native_test" >"$run_dir/logs/native/known-answer.log" 2>&1
env LD_LIBRARY_PATH="$devkit/lib:$native/lib:$work/thunks/murmurhash" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunks/murmurhash/x86_64" "$guest_test" >"$run_dir/logs/hecate/known-answer.log" 2>&1
cmp "$run_dir/logs/native/known-answer.log" "$run_dir/logs/hecate/known-answer.log"
[[ $(grep -c ' ...ok$' "$run_dir/logs/hecate/known-answer.log") == 19 ]]
python3 - "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({"schema_version": 2, "package": "murmurhash", "status": "pass", "tests_run": True, "known_answer_cases": 19, "execution_lanes": ["native", "Hecate"], "mechanism": "TLC Only"}, indent=2, sort_keys=True) + "\n")
PY
echo "Evidence: $run_dir"
