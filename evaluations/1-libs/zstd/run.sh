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
work=$repo_root/.work/evaluations/zstd
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "zstd", "release": "1.5.7", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "zstd:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$work/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$work/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"zstd","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$work/installed/native/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
mkdir -p "$work/tests/native" "$work/tests/guest"
run_logged "$run_dir/logs/preparation/test-native.log" cc -I"$native_prefix/include" "$recipe_dir/tests/workload.c" -L"$native_prefix/lib" -Wl,-rpath,"$native_prefix/lib" -lzstd -o "$work/tests/native/workload"
run_logged "$run_dir/logs/preparation/test-guest.log" "$devkit/bin/x86_64-linux-gnu-clang" --sysroot="$devkit/x86_64/sysroot" -I"$guest_prefix/include" "$recipe_dir/tests/workload.c" -L"$guest_prefix/lib" -Wl,-rpath,"$guest_prefix/lib" -lzstd -o "$work/tests/guest/workload"
native_upstream=$native_prefix/share/zstd/upstream-tests
guest_upstream=$guest_prefix/share/zstd/upstream-tests
native_cli=$native_upstream/bin/zstd
guest_cli=$guest_upstream/bin/zstd
chmod +x "$native_cli" "$guest_cli" "$recipe_dir/tests/QEMUWrapper.sh" "$recipe_dir/tests/QEMUDataGenWrapper.sh"
run_logged "$run_dir/logs/preparation/datagen-native.log" cc -O2 -I"$native_upstream/programs" "$native_upstream/programs/datagen.c" "$native_upstream/programs/lorem.c" "$native_upstream/tests/loremOut.c" "$native_upstream/tests/datagencli.c" -o "$work/tests/native/datagen"
run_logged "$run_dir/logs/preparation/datagen-guest.log" "$devkit/bin/x86_64-linux-gnu-clang" --sysroot="$devkit/x86_64/sysroot" -O2 -I"$guest_upstream/programs" "$guest_upstream/programs/datagen.c" "$guest_upstream/programs/lorem.c" "$guest_upstream/tests/loremOut.c" "$guest_upstream/tests/datagencli.c" -o "$work/tests/guest/datagen"
{
  "$nm_tool" -D --undefined-only --just-symbol-name "$work/tests/guest/workload"
  "$nm_tool" -D --undefined-only --just-symbol-name "$guest_cli"
} | sed 's/@.*//' | sort -u >"$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"zstd.so*"
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
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/zstd/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -DZDICT_STATIC_LINKING_ONLY -I"$hecate_prefix/include" -I"$hecate_prefix/share/zstd/upstream-tests/lib"
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
upstream_failures=0
native_suite=$work/zstd-play-native
hecate_suite=$work/zstd-play-hecate
mkdir -p "$native_suite/tests" "$hecate_suite/tests"
cp -R "$native_upstream/tests/." "$native_suite/tests/"
cp -R "$guest_upstream/tests/." "$hecate_suite/tests/"
cp -R "$native_upstream/programs" "$native_suite/programs"
cp -R "$guest_upstream/programs" "$hecate_suite/programs"
# These four invocations are upstream's alias checks. Prefix them just like the
# other guest-architecture invocations so they cross QEMU and the TLC thunk.
sed -i -E 's#^([[:space:]]*)\./(xz|unxz|lzma|unlzma)([[:space:]])#\1$EXE_PREFIX ./\2\3#' "$hecate_suite/tests/playTests.sh"
set +e
(cd "$native_suite" && EXE_PREFIX= ZSTD_BIN="$native_cli" DATAGEN_BIN="$work/tests/native/datagen" LD_LIBRARY_PATH="$native_prefix/lib" sh ./tests/playTests.sh) >"$run_dir/logs/native/upstream-playTests.log" 2>&1
native_suite_status=$?
(cd "$hecate_suite" && QEMU="$qemu" DEVKIT="$devkit" GUEST_LIB_DIR="$guest_prefix/lib" LORE_AE_HECATE=1 HOST_LIB_DIR="$hecate_prefix/lib" THUNK_DIR="$work/thunks/zstd" EXE_PREFIX="$recipe_dir/tests/QEMUWrapper.sh" ZSTD_BIN="$guest_cli" QEMU_WRAPPER="$recipe_dir/tests/QEMUWrapper.sh" GUEST_DATAGEN="$work/tests/guest/datagen" DATAGEN_BIN="$recipe_dir/tests/QEMUDataGenWrapper.sh" sh ./tests/playTests.sh) >"$run_dir/logs/hecate/upstream-playTests.log" 2>&1
hecate_suite_status=$?
set -e
if [[ $native_suite_status != 0 || $hecate_suite_status != 0 ]]; then upstream_failures=1; fi
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" "$native_suite_status" "$hecate_suite_status" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries, native_suite, hecate_suite = sys.argv[1:]
ok = native == hecate == native_suite == hecate_suite == "0"
data = {"schema_version": 2, "package": "zstd", "version": "1.5.7", "mechanism": "TLC Only", "status": "pass" if ok else "fail", "libraries": int(libraries), "native": {"exit_status": int(native)}, "hecate": {"exit_status": int(hecate)}, "output_match": True, "upstream_suite": {"test": "tests/playTests.sh", "native_exit_status": int(native_suite), "hecate_exit_status": int(hecate_suite), "excluded": ["CMake fullbench, fuzzer, and zstreamtest statically link libzstd and do not cross the shared-library ABI", "paramgrill is a performance tuner"]}}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
echo "Evidence: $run_dir"
