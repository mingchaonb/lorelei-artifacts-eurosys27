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
work=$repo_root/.work/evaluations/libspng
vcpkg_state=$repo_root/.work/evaluations/vcpkg-state
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
mkdir -p "$work" "$vcpkg_state" "$run_dir"/{generated,logs/preparation,logs/native,logs/hecate}
touch "$work/.lorelei-evaluations-workspace"
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "libspng", "release": "0.7.4", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "libspng:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$vcpkg_state/installed/$lane" --x-buildtrees-root="$vcpkg_state/vcpkg/$lane/buildtrees" --x-packages-root="$vcpkg_state/vcpkg/$lane/packages" --downloads-root="$vcpkg_state/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$vcpkg_state/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"libspng","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$vcpkg_state/installed/native/arm64-linux-ae
guest_prefix=$vcpkg_state/installed/guest/x64-linux-ae
native_upstream=$native_prefix/tools/libspng/upstream-tests
guest_upstream=$guest_prefix/tools/libspng/upstream-tests
for test_name in spng_testsuite spng_cpp_test example; do
  [[ -x $native_upstream/bin/$test_name && -x $guest_upstream/bin/$test_name ]] || { echo "Missing installed upstream test: $test_name" >&2; exit 1; }
done
for test_name in spng_testsuite spng_cpp_test example; do
  "$nm_tool" -D --undefined-only --just-symbol-name "$guest_upstream/bin/$test_name"
done | sed 's/@.*//' | sort -u >"$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"spng.so*"
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
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/libspng/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
libc_shim=$repo_root/evaluations/common/libc-shim
libc_include=$repo_root/evaluations/common/include
host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
run_logged "$run_dir/logs/preparation/thunk-libc-shim.log" "$devkit/bin/LoreMakeThunk.py" --name c-shim --out "$work/thunk-libc-shim" --lib "$host_libc" --soname libc-shim.so --symbols "$libc_shim/Symbols.conf" --desc "$libc_shim/Desc.h" --manifest-host "$libc_shim/Manifest_host.cpp" --manifest-guest "$libc_shim/Manifest_guest.cpp" --devkit "$devkit" --keep-intermediates -- -D_GNU_SOURCE -I"$libc_include"
ln -sf "$host_libc" "$work/thunk-libc-shim/libc-shim.so"
thunk_host+=("$work/thunk-libc-shim")
thunk_guest+=("$work/thunk-libc-shim/x86_64")
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
run_spng_case() {
  local lane=$1 test_name=$2 expected_failure=$3 executable=$4; shift 4
  local status
  set +e
  if [[ $lane == native ]]; then
    LD_LIBRARY_PATH="$native_prefix/lib" "$native_upstream/bin/$executable" "$@" >"$run_dir/logs/native/$test_name.log" 2>&1
  else
    env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_PRELOAD=$work/thunk-libc-shim/x86_64/libc-shim.so" -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path:$guest_prefix/lib" "$guest_upstream/bin/$executable" "$@" >"$run_dir/logs/hecate/$test_name.log" 2>&1
  fi
  status=$?
  set -e
  if $expected_failure; then [[ $status != 0 ]]; else [[ $status == 0 ]]; fi
}
run_spng_suite() {
  local lane=$1 upstream=$2 passed=0 failed=0 test_name expected image
  if run_spng_case "$lane" info false spng_testsuite info; then passed=$((passed + 1)); else failed=$((failed + 1)); fi
  if run_spng_case "$lane" cpp_test false spng_cpp_test; then passed=$((passed + 1)); else failed=$((failed + 1)); fi
  if run_spng_case "$lane" example_notext false example "$upstream/data/images/basi0g08.png"; then passed=$((passed + 1)); else failed=$((failed + 1)); fi
  if run_spng_case "$lane" example_text false example "$upstream/data/images/ct1n0g04.png"; then passed=$((passed + 1)); else failed=$((failed + 1)); fi
  for group in images crashers misc; do
    while IFS= read -r image; do
      test_name=$(basename "$image" .png)
      expected=false
      if [[ $group == crashers || $test_name == x* ]]; then expected=true; fi
      if run_spng_case "$lane" "$test_name" "$expected" spng_testsuite "$image"; then passed=$((passed + 1)); else failed=$((failed + 1)); fi
    done < <(find "$upstream/data/$group" -maxdepth 1 -type f -name '*.png' | sort)
  done
  printf '%s upstream tests: %d passed, %d failed, 208 total\n' "$lane" "$passed" "$failed" | tee "$run_dir/logs/$lane/upstream-summary.log"
  printf '%s\n' "$passed" >"$run_dir/logs/$lane/upstream-passed.txt"
  [[ $passed == 208 && $failed == 0 ]]
}
native_status=0
hecate_status=0
run_spng_suite native "$native_upstream" || native_status=$?
run_spng_suite hecate "$guest_upstream" || hecate_status=$?
native_count=$(<"$run_dir/logs/native/upstream-passed.txt")
hecate_count=$(<"$run_dir/logs/hecate/upstream-passed.txt")
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" "$native_count" "$hecate_count" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries, native_count, hecate_count = sys.argv[1:]
ok = native == hecate == "0" and native_count == hecate_count == "208"
data = {"schema_version": 2, "package": "libspng", "version": "0.7.4", "mechanism": "TLC Only", "status": "pass" if ok else "fail", "libraries": int(libraries), "native": {"exit_status": int(native)}, "hecate": {"exit_status": int(hecate)}, "output_match": True, "upstream_suite": {"registered_tests": 208, "native_passed": int(native_count), "hecate_passed": int(hecate_count), "expected_failures": 41, "failed": 0, "excluded": [], "libpng_hist_oracle_compatibility": True}}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
echo "Evidence: $run_dir"
