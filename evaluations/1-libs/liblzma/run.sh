#!/usr/bin/env bash
set -euo pipefail
recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
overlay_dir=$repo_root/vcpkg-overlay
devkit=
reference=false
install_only=false
verbose=false
positional=()
while (($#)); do
  case $1 in
    --reference) reference=true ;;
    --install-only) install_only=true ;;
    --verbose) verbose=true ;;
    -h|--help) echo "Usage: $0 [--reference] [--install-only] [--verbose] /path/to/lorelei-devkit"; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) positional+=("$1") ;;
  esac
  shift
done
[[ ${#positional[@]} == 1 ]] || { echo "Expected one devkit path" >&2; exit 2; }
devkit=$(realpath "${positional[0]}")
qemu=$(realpath -m "${QEMU:-$devkit/bin/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || command -v nm)
work=$repo_root/.work/evaluations/liblzma
results_root=$recipe_dir/results
kind=evaluator
if $reference; then results_root=$recipe_dir/reference-results; kind=reference; fi
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id
[[ -x $vcpkg ]] || { echo "Bootstrap ./vcpkg before running this recipe" >&2; exit 2; }
for path in bin/LoreMakeThunk.py bin/x86_64-linux-gnu-clang x86_64/sysroot; do
  [[ -e $devkit/$path ]] || { echo "Missing devkit entry: $devkit/$path" >&2; exit 2; }
done
if ! $install_only; then [[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }; fi
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then echo "Refusing unmarked work directory: $work" >&2; exit 2; fi
if [[ -e $work ]]; then cmake -E remove_directory "$work"; fi
mkdir -p "$work" "$run_dir"/{generated,logs/preparation,logs/native,logs/hecate}
touch "$work/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1
run_logged() { local log=$1 status; shift; printf '  $'; printf ' %q' "$@"; printf '\n'; if ! $verbose; then "$@" >"$log" 2>&1; return; fi; set +e; "$@" 2>&1 | tee "$log"; status=${PIPESTATUS[0]}; set -e; return "$status"; }
{
  date -u --iso-8601=seconds
  uname -a
  cat /etc/os-release
  lscpu
  uptime
  "$vcpkg" version
} >"$run_dir/environment.txt" 2>&1
python3 - "$run_dir/meta.json" "$run_id" "$kind" "$devkit" "$qemu" "$install_only" <<'PY'
import json, pathlib, sys
out, run_id, kind, devkit, qemu, install_only = sys.argv[1:]
data = {"schema_version": 2, "experiment_id": run_id, "package": "liblzma", "release": "5.8.3", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "liblzma:$triplet" --no-binarycaching --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$work/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$work/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"liblzma","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$work/installed/native/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
mkdir -p "$work/tests/native" "$work/tests/guest"
run_logged "$run_dir/logs/preparation/test-native.log" cc -I"$native_prefix/include" "$recipe_dir/tests/workload.c" -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -llzma -o "$work/tests/native/workload"
run_logged "$run_dir/logs/preparation/test-guest.log" "$devkit/bin/x86_64-linux-gnu-clang" --sysroot="$devkit/x86_64/sysroot" -I"$guest_prefix/include" "$recipe_dir/tests/workload.c" -L"$guest_prefix/lib" -Wl,-rpath,"$guest_prefix/lib" -llzma -o "$work/tests/guest/workload"
native_build=$work/vcpkg/native/buildtrees/liblzma/arm64-linux-ae-rel
guest_build=$work/vcpkg/guest/buildtrees/liblzma/x64-linux-ae-rel
qemu_wrapper=$overlay_dir/ports/liblzma/lorelei/QEMUWrapper.sh
tool_wrapper=$overlay_dir/ports/liblzma/lorelei/ToolWrapper.sh
chmod +x "$qemu_wrapper" "$tool_wrapper"
for tool in xz xzdec; do
  [[ -f $guest_build/$tool ]] || { echo "Missing upstream tool: $tool" >&2; exit 1; }
  mv "$guest_build/$tool" "$guest_build/$tool.guest"
  cp "$tool_wrapper" "$guest_build/$tool"
done
{
  "$nm_tool" -D --undefined-only --just-symbol-name "$work/tests/guest/workload"
  find "$guest_build/tests_bin" -maxdepth 1 -type f -perm -111 -exec "$nm_tool" -D --undefined-only --just-symbol-name {} \;
  "$nm_tool" -D --undefined-only --just-symbol-name "$guest_build/xz.guest"
  "$nm_tool" -D --undefined-only --just-symbol-name "$guest_build/xzdec.guest"
} | sed 's/@.*//' | sort -u >"$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"lzma.so*"
for pattern in "${patterns[@]}"; do
  host_lib=$(find "$hecate_prefix/lib" -maxdepth 1 -type f -name "lib$pattern" | sort | head -1)
  [[ -n $host_lib ]] || { echo "Host DSO not found for $pattern" >&2; exit 1; }
  lib_name=$(basename "$host_lib" | sed -E 's/^lib//; s/\.so.*$//')
  audit="$run_dir/generated/elf/$lib_name"
  mkdir -p "$audit"
  readelf -d "$host_lib" >"$audit/dynamic.txt"
  readelf -Ws "$host_lib" >"$audit/symbols.txt"
  file "$host_lib" >"$audit/file.txt"
  "$nm_tool" -D --defined-only --format=posix "$host_lib" | awk '$2 == "T" || $2 == "W" {n=$1; sub(/@.*/, "", n); print n}' | sort -u >"$audit/functions.txt"
  comm -12 "$run_dir/generated/guest-undefined.txt" "$audit/functions.txt" >"$audit/used-functions.txt"
  { echo '[Function]'; cat "$audit/used-functions.txt"; } >"$audit/Symbols.conf"
  [[ -s $audit/used-functions.txt ]] || { echo "No tested functions found for $lib_name" >&2; exit 1; }
  thunk="$work/thunks/$lib_name"
  version_map=$(find "$work/vcpkg/native/buildtrees/liblzma/src" -path '*/src/liblzma/liblzma_linux.map' | head -1)
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/liblzma/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --gtl-arg="-Wl,--version-script=$version_map" --gtl-arg=-Wl,--undefined-version --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
set +e
LD_LIBRARY_PATH="$native_prefix/lib" "$work/tests/native/workload" 2>&1 | tee "$run_dir/logs/native/workload.log"
native_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$native_status" >"$run_dir/logs/native/exit-status.txt"
set +e
env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path" "$work/tests/guest/workload" 2>&1 | tee "$run_dir/logs/hecate/workload.log"
hecate_status=${PIPESTATUS[0]}
set -e
printf '%s\n' "$hecate_status" >"$run_dir/logs/hecate/exit-status.txt"
sed '/no version information available/d' "$run_dir/logs/native/workload.log" >"$run_dir/logs/native/workload.normalized"
sed '/no version information available/d' "$run_dir/logs/hecate/workload.log" >"$run_dir/logs/hecate/workload.normalized"
cmp "$run_dir/logs/native/workload.normalized" "$run_dir/logs/hecate/workload.normalized"
set +e
LD_LIBRARY_PATH="$native_prefix/lib" ctest --test-dir "$native_build" --output-on-failure >"$run_dir/logs/native/upstream-ctest.log" 2>&1
native_ctest_status=$?
QEMU="$qemu" DEVKIT="$devkit" QEMU_WRAPPER="$qemu_wrapper" LORE_AE_HECATE=1 HOST_LIB_DIR="$hecate_prefix/lib" THUNK_DIR="$work/thunks/lzma" GUEST_LIB_DIR="$guest_prefix/lib" ctest --test-dir "$guest_build" --output-on-failure >"$run_dir/logs/hecate/upstream-ctest.log" 2>&1
hecate_ctest_status=$?
set -e
native_count=$(sed -nE 's/.*100% tests passed, 0 tests failed out of ([0-9]+).*/\1/p' "$run_dir/logs/native/upstream-ctest.log" | tail -1)
hecate_count=$(sed -nE 's/.*100% tests passed, 0 tests failed out of ([0-9]+).*/\1/p' "$run_dir/logs/hecate/upstream-ctest.log" | tail -1)
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" "$native_ctest_status" "$hecate_ctest_status" "${native_count:-0}" "${hecate_count:-0}" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries, native_ctest, hecate_ctest, native_count, hecate_count = sys.argv[1:]
ok = native == hecate == native_ctest == hecate_ctest == "0" and native_count == hecate_count == "19"
data = {"schema_version": 2, "package": "liblzma", "version": "5.8.3", "mechanism": "TLC Only", "status": "pass" if ok else "fail", "libraries": int(libraries), "native": {"exit_status": int(native)}, "hecate": {"exit_status": int(hecate)}, "output_match": True, "upstream_suite": {"registered_tests": 19, "native_passed": int(native_count), "hecate_passed": int(hecate_count)}}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
echo "Evidence: $run_dir"
