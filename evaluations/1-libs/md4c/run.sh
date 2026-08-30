#!/usr/bin/env bash
set -euo pipefail
recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
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
    -h|--help) echo "Usage: $0 [--reference] [--install-only] [--verbose]"; exit 0 ;;
    --*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
  esac
  shift
done
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/../lorelei-ae/build/install}")
default_qemu=$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64
qemu=$(realpath -m "${QEMU:-$default_qemu}")
vcpkg=$repo_root/vcpkg/vcpkg
nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || command -v nm)
work=$repo_root/.work/evaluations/md4c
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "md4c", "release": "0.5.3", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "md4c:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$work/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"md4c","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$work/installed/native/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
: >"$run_dir/generated/guest-undefined.txt"
suite_native=$native_prefix/tools/md4c/upstream-tests
suite_guest=$guest_prefix/tools/md4c/upstream-tests
for test_binary in "$suite_native/bin/md2html" "$suite_guest/bin/md2html"; do
  [[ -x $test_binary ]] || { echo "Installed md2html test program not found: $test_binary" >&2; exit 1; }
done
"$nm_tool" -D --undefined-only --just-symbol-name "$suite_guest/bin/md2html" | sed 's/@.*//' >>"$run_dir/generated/guest-undefined.txt"
sort -u -o "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"md4c-html.so*"
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
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/md4c/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
native_status=0
hecate_status=0
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries = sys.argv[1:]
ok = native == hecate == "0"
data = {"schema_version": 2, "package": "md4c", "version": "0.5.3", "mechanism": "TLC Only", "status": "running", "libraries": int(libraries)}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
run_md4c_suite() {
  local lane=$1 suite=$2 program=$3
  local output=$run_dir/logs/$lane/upstream.log
  : >"$output"
  (
    cd "$suite"
    for spec in spec.txt regressions.txt spec-*.txt; do
      echo "SPEC=$spec"
      python3 run-testsuite.py -p "$program" -s "$spec"
    done
  ) >>"$output" 2>&1
  (cd "$suite" && python3 pathological-tests.py -p "$program") >"$run_dir/logs/$lane/upstream-pathological.log" 2>&1
  sed -E 's#^/.*/pathological-tests.py:#<SUITE>/pathological-tests.py:#; s/\[PASSED\] [0-9]+\.[0-9]+ secs/[PASSED] <TIME> secs/' "$run_dir/logs/$lane/upstream-pathological.log" >"$run_dir/logs/$lane/upstream-pathological-normalized.log"
}
mkdir -p "$work/tests/native" "$work/tests/guest"
native_runner=$work/tests/native/md2html-runner
hecate_runner=$work/tests/guest/md2html-runner
printf '%s\n' '#!/usr/bin/env bash' 'exec env LD_LIBRARY_PATH="$MD4C_NATIVE_LIB" "$MD4C_NATIVE_BIN" "$@"' >"$native_runner"
printf '%s\n' '#!/usr/bin/env bash' 'exec env LD_LIBRARY_PATH="$MD4C_HOST_ENV" "$MD4C_QEMU" -L "$MD4C_SYSROOT" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$MD4C_GUEST_ENV" "$MD4C_GUEST_BIN" "$@"' >"$hecate_runner"
chmod +x "$native_runner" "$hecate_runner"
export MD4C_NATIVE_LIB=$native_prefix/lib MD4C_NATIVE_BIN=$suite_native/bin/md2html
export MD4C_HOST_ENV=$devkit/lib:$hecate_prefix/lib:$host_path MD4C_QEMU=$qemu MD4C_SYSROOT=$devkit/x86_64/sysroot MD4C_GUEST_ENV=$devkit/x86_64/lib:$guest_path MD4C_GUEST_BIN=$suite_guest/bin/md2html
run_md4c_suite native "$suite_native" "$native_runner"
run_md4c_suite hecate "$suite_guest" "$hecate_runner"
for lane in native hecate; do
  sed -E 's#^/.*/normalize.py:#<SUITE>/normalize.py:#' "$run_dir/logs/$lane/upstream.log" >"$run_dir/logs/$lane/upstream-normalized.log"
done
cmp "$run_dir/logs/native/upstream-normalized.log" "$run_dir/logs/hecate/upstream-normalized.log"
cmp "$run_dir/logs/native/upstream-pathological-normalized.log" "$run_dir/logs/hecate/upstream-pathological-normalized.log"
[[ $(grep -c ' passed, 0 failed, 0 errored, 0 skipped$' "$run_dir/logs/hecate/upstream.log") == 10 ]]
grep -q '^29 passed, 0 failed, 0 errored$' "$run_dir/logs/hecate/upstream-pathological.log"
python3 - "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data.update({"status": "pass", "native": {"exit_status": 0}, "hecate": {"exit_status": 0}, "output_match": True})
data["upstream"] = {"tests": 818, "native_exit_status": 0, "hecate_exit_status": 0, "output_match": True, "installed_by_vcpkg": True}
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
echo "ALL TESTS PASSED: native and Hecate"
echo "Evidence: $run_dir"
