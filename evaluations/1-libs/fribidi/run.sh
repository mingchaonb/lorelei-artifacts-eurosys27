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
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
default_qemu=$repo_root/vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64
qemu=$(realpath -m "${QEMU:-$default_qemu}")
vcpkg=$repo_root/vcpkg/vcpkg
nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || command -v nm)
work=$repo_root/.work/evaluations/fribidi
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "fribidi", "release": "1.0.16", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "fribidi:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$work/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"fribidi","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$work/installed/native/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
: >"$run_dir/generated/guest-undefined.txt"
suite_native=$native_prefix/tools/fribidi/upstream-tests
suite_guest=$guest_prefix/tools/fribidi/upstream-tests
for test_binary in "$suite_guest/bin/"*; do
  "$nm_tool" -D --undefined-only --just-symbol-name "$test_binary" | sed 's/@.*//' >>"$run_dir/generated/guest-undefined.txt"
done
sort -u -o "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"fribidi.so*"
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
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/fribidi/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include" -I"$hecate_prefix/include/fribidi"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
run_logged "$run_dir/logs/preparation/guest-metadata.log" "$devkit/bin/x86_64-linux-gnu-clang" --sysroot="$devkit/x86_64/sysroot" -shared -fPIC "$overlay_dir/ports/fribidi/lorelei/GuestMetadata.c" -o "$work/thunks/guest-metadata.so"
native_status=0
hecate_status=0
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries = sys.argv[1:]
ok = native == hecate == "0"
data = {"schema_version": 2, "package": "fribidi", "version": "1.0.16", "mechanism": "TLC Only", "status": "running", "libraries": int(libraries)}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
for lane in native hecate; do
  suite=$suite_native
  [[ $lane == hecate ]] && suite=$suite_guest
  output=$run_dir/logs/$lane/upstream.log
  : >"$output"
  while read -r charset suffix; do
    name=${charset}_${suffix}
    actual=$work/${name}-${lane}.actual
    echo "RUN $name" >>"$output"
    if [[ $lane == native ]]; then
      env LD_LIBRARY_PATH="$native_prefix/lib" "$suite/bin/fribidi" --test --charset "$charset" "$suite/data/test_${name}.input" >"$actual"
    else
      env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_PRELOAD=$work/thunks/guest-metadata.so" -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path" "$suite/bin/fribidi" --test --charset "$charset" "$suite/data/test_${name}.input" >"$actual"
    fi
    cmp "$suite/data/test_${name}.reference" "$actual"
    echo "PASS $name" >>"$output"
  done <<'EOF'
CapRTL explicit
CapRTL implicit
CapRTL isolate
ISO8859-8 hebrew
UTF-8 persian
UTF-8 reordernsm
EOF
  for test_name in BidiTest BidiCharacterTest; do
    echo "RUN $test_name" >>"$output"
    if [[ $lane == native ]]; then
      env LD_LIBRARY_PATH="$native_prefix/lib" "$suite/bin/$test_name" "$suite/data/unicode-conformance/$test_name.txt" >>"$output" 2>&1
    else
      env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_PRELOAD=$work/thunks/guest-metadata.so" -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path" "$suite/bin/$test_name" "$suite/data/unicode-conformance/$test_name.txt" >>"$output" 2>&1
    fi
    echo "PASS $test_name" >>"$output"
  done
  grep -E '^(RUN|PASS) ' "$output" >"$run_dir/logs/$lane/upstream-status.log"
done
cmp "$run_dir/logs/native/upstream-status.log" "$run_dir/logs/hecate/upstream-status.log"
python3 - "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data.update({"status": "pass", "native": {"exit_status": 0}, "hecate": {"exit_status": 0}, "output_match": True})
data["upstream"] = {"tests": 8, "native_exit_status": 0, "hecate_exit_status": 0, "output_match": True, "installed_by_vcpkg": True}
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
echo "ALL TESTS PASSED: native and Hecate"
echo "Evidence: $run_dir"
