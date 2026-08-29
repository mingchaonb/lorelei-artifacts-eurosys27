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
default_qemu=$devkit/bin/qemu-x86_64
[[ -x $default_qemu || ! -x $devkit/../../../qemu-ae/build/qemu-x86_64 ]] || default_qemu=$devkit/../../../qemu-ae/build/qemu-x86_64
qemu=$(realpath -m "${QEMU:-$default_qemu}")
vcpkg=$repo_root/vcpkg/vcpkg
nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || command -v nm)
work=$repo_root/.work/evaluations/jansson
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "jansson", "release": "2.15.1", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "jansson:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$work/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"jansson","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$work/installed/native/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
: >"$run_dir/generated/guest-undefined.txt"
suite_native=$native_prefix/tools/jansson/upstream-tests
suite_guest=$guest_prefix/tools/jansson/upstream-tests
mapfile -t installed_guest_tests < <(find "$suite_guest/bin" -maxdepth 1 -type f -perm -111 | sort)
[[ ${#installed_guest_tests[@]} == 20 ]] || { echo "Expected 20 installed Jansson test programs" >&2; exit 1; }
for test_binary in "${installed_guest_tests[@]}"; do
  "$nm_tool" -D --undefined-only --just-symbol-name "$test_binary" | sed 's/@.*//' >>"$run_dir/generated/guest-undefined.txt"
done
sort -u -o "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"jansson.so*"
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
  version_script=$overlay_dir/ports/jansson/lorelei/jansson.sym
  cp "$version_script" "$audit/jansson.sym"
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/jansson/lorelei/Desc.h" --manifest-guest "$overlay_dir/ports/jansson/lorelei/Manifest_guest.cpp" --gtl-alias "$(basename "$host_lib")" --gtl-arg=-Wl,--undefined-version --gtl-arg="-Wl,--version-script=$version_script" --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include" -I"$recipe_dir/upstream/include"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
libc_shim=$recipe_dir/upstream/libc-shim
host_libc=$(/usr/bin/cc -print-file-name=libc.so.6)
run_logged "$run_dir/logs/preparation/thunk-libc-shim.log" "$devkit/bin/LoreMakeThunk.py" --name c-shim --out "$work/thunk-libc-shim" --lib "$host_libc" --soname libc-shim.so --symbols "$libc_shim/Symbols.conf" --desc "$libc_shim/Desc.h" --manifest-host "$libc_shim/Manifest_host.cpp" --manifest-guest "$libc_shim/Manifest_guest.cpp" --devkit "$devkit" --keep-intermediates -- -D_GNU_SOURCE -I"$recipe_dir/upstream/include"
ln -sf "$host_libc" "$work/thunk-libc-shim/libc-shim.so"
native_status=0
hecate_status=0
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries = sys.argv[1:]
ok = native == hecate == "0"
data = {"schema_version": 2, "package": "jansson", "version": "2.15.1", "mechanism": "TLC Only", "status": "running", "libraries": int(libraries)}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
run_jansson_test() {
  local lane=$1 binary=$2
  shift 2
  if [[ $lane == native ]]; then
    env LD_LIBRARY_PATH="$native_prefix/lib" "$binary" "$@"
  else
    env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path:$work/thunk-libc-shim" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_PRELOAD=$work/thunk-libc-shim/x86_64/libc-shim.so" -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path:$work/thunk-libc-shim/x86_64" "$binary" "$@"
  fi
}
api_tests=(test_array test_chaos test_chaos_realloc test_copy test_dump test_dump_callback test_equal test_fixed_size test_load test_load_callback test_loadb test_number test_object test_pack test_simple test_sprintf test_unpack test_memory_funcs test_memory_funcs_realloc)
for lane in native hecate; do
  lane_suite=$suite_native
  [[ $lane == hecate ]] && lane_suite=$suite_guest
  output=$run_dir/logs/$lane/upstream.log
  mkdir -p "$work/upstream/$lane"
  : >"$output"
  count=0
  for test_name in "${api_tests[@]}"; do
    echo "RUN $test_name" >>"$output"
    (cd "$work/upstream/$lane" && run_jansson_test "$lane" "$lane_suite/bin/$test_name") >>"$output" 2>&1
    echo "PASS $test_name" >>"$output"
    count=$((count + 1))
  done
  for suite_name in encoding-flags valid invalid invalid-unicode; do
    for test_dir in "$lane_suite/suites/$suite_name"/*; do
      [[ -d $test_dir ]] || continue
      [[ -e $test_dir/skip_if_dtoa ]] && continue
      test_name=${suite_name}__$(basename "$test_dir")
      echo "RUN $test_name" >>"$output"
      run_jansson_test "$lane" "$lane_suite/bin/json_process" "$test_dir" >>"$output" 2>&1
      echo "PASS $test_name" >>"$output"
      count=$((count + 1))
      if [[ $suite_name == valid || $suite_name == invalid ]] && [[ ! -e $test_dir/nostrip ]]; then
        echo "RUN ${test_name}__strip" >>"$output"
        run_jansson_test "$lane" "$lane_suite/bin/json_process" --strip "$test_dir" >>"$output" 2>&1
        echo "PASS ${test_name}__strip" >>"$output"
        count=$((count + 1))
      fi
    done
  done
  [[ $count == 215 ]] || { echo "Expected 215 Jansson tests, ran $count" >&2; exit 1; }
done
cmp "$run_dir/logs/native/upstream.log" "$run_dir/logs/hecate/upstream.log"
python3 - "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data.update({"status": "pass", "native": {"exit_status": 0}, "hecate": {"exit_status": 0}, "output_match": True})
data["upstream"] = {"tests": 215, "native_exit_status": 0, "hecate_exit_status": 0, "output_match": True, "installed_by_vcpkg": True}
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
echo "ALL TESTS PASSED: native and Hecate"
echo "Evidence: $run_dir"
