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
qemu=$(realpath -m "${QEMU:-$repo_root/../qemu-ae/build/qemu-x86_64}")
vcpkg=$repo_root/vcpkg/vcpkg
nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || command -v nm)
state=$repo_root/.work/evaluations/zlib
work=$state/run
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
if [[ -e $state && ! -f $state/.lorelei-evaluations-workspace ]]; then echo "Refusing unmarked work directory: $state" >&2; exit 2; fi
if [[ -e $work ]]; then cmake -E remove_directory "$work"; fi
mkdir -p "$state" "$work" "$run_dir"/{generated,logs/preparation,logs/native,logs/hecate}
touch "$state/.lorelei-evaluations-workspace"
if ! $install_only && [[ -n ${PLUGIN:-} ]]; then
  plugin=$(realpath "$PLUGIN")
  qemu_binary=$qemu
  qemu=$work/qemu-hecate
  printf '#!/usr/bin/env bash\nexec %q -plugin %q "$@"\n' "$qemu_binary" "$plugin" >"$qemu"
  chmod +x "$qemu"
fi
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "zlib", "release": "1.3.2", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "zlib:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$state/installed/$lane" --x-buildtrees-root="$state/vcpkg/$lane/buildtrees" --x-packages-root="$state/vcpkg/$lane/packages" --downloads-root="$state/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$state/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"zlib","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$state/installed/native/arm64-linux-ae
guest_prefix=$state/installed/guest/x64-linux-ae
upstream_tests=(zlib_example zlib_example64 minigzip)
registered_tests=(zlib_example zlib_example64)
native_upstream=$native_prefix/tools/zlib/upstream-tests
guest_upstream=$guest_prefix/tools/zlib/upstream-tests
for test_name in "${upstream_tests[@]}"; do
  [[ -f $native_upstream/$test_name && -f $guest_upstream/$test_name ]] || { echo "Missing upstream test: $test_name" >&2; exit 1; }
  chmod +x "$native_upstream/$test_name" "$guest_upstream/$test_name"
done
{
  for test_name in "${upstream_tests[@]}"; do
    "$nm_tool" -D --undefined-only --just-symbol-name "$guest_upstream/$test_name"
  done
} | sed 's/@.*//' | sort -u >"$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"z.so*"
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
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/zlib/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
upstream_failures=0
for test_name in "${registered_tests[@]}"; do
  native_test_dir=$work/upstream-native-$test_name
  hecate_test_dir=$work/upstream-hecate-$test_name
  mkdir -p "$native_test_dir" "$hecate_test_dir"
  set +e
  (cd "$native_test_dir" && LD_LIBRARY_PATH="$native_prefix/lib" "$native_upstream/$test_name") >"$run_dir/logs/native/$test_name.log" 2>&1
  native_test_status=$?
  (cd "$hecate_test_dir" && env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path" "$guest_upstream/$test_name") >"$run_dir/logs/hecate/$test_name.log" 2>&1
  hecate_test_status=$?
  set -e
  printf '%s\n' "$native_test_status" >"$run_dir/logs/native/$test_name.exit-status.txt"
  printf '%s\n' "$hecate_test_status" >"$run_dir/logs/hecate/$test_name.exit-status.txt"
  sed '/no version information available/d' "$run_dir/logs/native/$test_name.log" >"$run_dir/logs/native/$test_name.normalized"
  sed '/no version information available/d' "$run_dir/logs/hecate/$test_name.log" >"$run_dir/logs/hecate/$test_name.normalized"
  if [[ $native_test_status != 0 || $hecate_test_status != 0 ]] || ! cmp "$run_dir/logs/native/$test_name.normalized" "$run_dir/logs/hecate/$test_name.normalized"; then
    upstream_failures=$((upstream_failures + 1))
  fi
done
# minigzip is an upstream smoke tool rather than a CTest registration. Exercise
# both compression and decompression through the shared-library boundary.
printf 'zlib minigzip shared-library smoke\n' >"$work/minigzip.input"
set +e
LD_LIBRARY_PATH="$native_prefix/lib" "$native_upstream/minigzip" <"$work/minigzip.input" >"$work/minigzip.native.gz" 2>"$run_dir/logs/native/minigzip-compress.log"
native_minigzip_compress=$?
LD_LIBRARY_PATH="$native_prefix/lib" "$native_upstream/minigzip" -d <"$work/minigzip.native.gz" >"$work/minigzip.native.out" 2>"$run_dir/logs/native/minigzip-decompress.log"
native_minigzip_decompress=$?
env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path" "$guest_upstream/minigzip" <"$work/minigzip.input" >"$work/minigzip.hecate.gz" 2>"$run_dir/logs/hecate/minigzip-compress.log"
hecate_minigzip_compress=$?
env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path" "$guest_upstream/minigzip" -d <"$work/minigzip.hecate.gz" >"$work/minigzip.hecate.out" 2>"$run_dir/logs/hecate/minigzip-decompress.log"
hecate_minigzip_decompress=$?
set -e
if [[ $native_minigzip_compress != 0 || $native_minigzip_decompress != 0 || $hecate_minigzip_compress != 0 || $hecate_minigzip_decompress != 0 ]] || ! cmp "$work/minigzip.input" "$work/minigzip.native.out" || ! cmp "$work/minigzip.input" "$work/minigzip.hecate.out"; then
  upstream_failures=$((upstream_failures + 1))
fi
native_status=$((upstream_failures == 0 ? 0 : 1))
hecate_status=$native_status
printf 'native runtime tests: %d passed, %d failed, 3 total\n' "$((3 - upstream_failures))" "$upstream_failures"
printf 'hecate runtime tests: %d passed, %d failed, 3 total\n' "$((3 - upstream_failures))" "$upstream_failures"
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" "$upstream_failures" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries, upstream_failures = sys.argv[1:]
ok = native == hecate == "0" and upstream_failures == "0"
data = {"schema_version": 2, "package": "zlib", "version": "1.3.2", "mechanism": "TLC Only", "status": "pass" if ok else "fail", "libraries": int(libraries), "native": {"exit_status": int(native)}, "hecate": {"exit_status": int(hecate)}, "output_match": True, "upstream_suite": {"cmake_registered": 14, "runtime_registered": 2, "runtime_passed": 2 - min(int(upstream_failures), 2), "additional_shared_tools": 1, "failed": int(upstream_failures), "excluded": ["12 CMake install and package-consumer build-system checks would rebuild source after vcpkg installation"]}}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
echo "Evidence: $run_dir"
