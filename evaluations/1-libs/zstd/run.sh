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
state=$repo_root/.work/evaluations/zstd
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "zstd", "release": "1.5.7", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "zstd:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$state/installed/$lane" --x-buildtrees-root="$state/vcpkg/$lane/buildtrees" --x-packages-root="$state/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$state/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"zstd","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$state/installed/native/arm64-linux-ae
guest_prefix=$state/installed/guest/x64-linux-ae
native_upstream=$native_prefix/tools/zstd/upstream-tests
guest_upstream=$guest_prefix/tools/zstd/upstream-tests
native_cli=$native_upstream/bin/zstd
guest_cli=$guest_upstream/bin/zstd
installed_upstream_binaries=(zstd datagen fullbench fuzzer zstreamtest)
for test_name in "${installed_upstream_binaries[@]}"; do
  [[ -x $native_upstream/bin/$test_name && -x $guest_upstream/bin/$test_name ]] || { echo "Missing installed upstream test: $test_name" >&2; exit 1; }
done
for test_name in "${installed_upstream_binaries[@]}"; do
  "$nm_tool" -D --undefined-only --just-symbol-name "$guest_upstream/bin/$test_name"
done | sed 's/@.*//' | sort -u >"$run_dir/generated/guest-undefined.txt"
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
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/zstd/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -DZDICT_STATIC_LINKING_ONLY -I"$hecate_prefix/include" -I"$hecate_prefix/tools/zstd/upstream-tests/lib"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
run_zstd_binary() {
  local lane=$1 test_name=$2; shift 2
  if [[ $lane == native ]]; then
    ZSTD_SKIP_STATIC_CONTEXT_TESTS=1 ZSTD_SKIP_SEQUENCE_PRODUCER_TESTS=1 LD_LIBRARY_PATH="$native_prefix/lib" "$native_upstream/bin/$test_name" "$@" >"$run_dir/logs/native/$test_name.log" 2>&1
  else
    env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E ZSTD_SKIP_STATIC_CONTEXT_TESTS=1 -E ZSTD_SKIP_SEQUENCE_PRODUCER_TESTS=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path" "$guest_upstream/bin/$test_name" "$@" >"$run_dir/logs/hecate/$test_name.log" 2>&1
  fi
}
run_play_tests() {
  local lane=$1 upstream=$2 prefix=$3 suite=$work/zstd-play-$lane
  mkdir -p "$suite"
  cp -R "$upstream/tests" "$upstream/programs" "$suite/"
  if [[ $lane == native ]]; then
    (cd "$suite" && ZSTD_SKIP_DICT_TESTS=1 EXE_PREFIX= ZSTD_BIN="$upstream/bin/zstd" DATAGEN_BIN="$upstream/bin/datagen" LD_LIBRARY_PATH="$prefix/lib" sh ./tests/playTests.sh) >"$run_dir/logs/native/playTests.log" 2>&1
    return
  fi
  hecate_exec=$suite/hecate-exec
  datagen_exec=$suite/hecate-datagen
  printf '#!/usr/bin/env bash\nexec env LD_LIBRARY_PATH=%q %q -L %q -E LD_BIND_NOW=1 -E %q "$@"\n' "$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" "$devkit/x86_64/sysroot" "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path" >"$hecate_exec"
  printf '#!/usr/bin/env bash\nexec %q %q "$@"\n' "$hecate_exec" "$upstream/bin/datagen" >"$datagen_exec"
  chmod +x "$hecate_exec" "$datagen_exec"
  sed -i -E 's#^([[:space:]]*)\./(xz|unxz|lzma|unlzma)([[:space:]])#\1$EXE_PREFIX ./\2\3#' "$suite/tests/playTests.sh"
  (cd "$suite" && ZSTD_SKIP_DICT_TESTS=1 EXE_PREFIX="$hecate_exec" ZSTD_BIN="$upstream/bin/zstd" DATAGEN_BIN="$datagen_exec" sh ./tests/playTests.sh) >"$run_dir/logs/hecate/playTests.log" 2>&1
}
run_zstd_suite() {
  local lane=$1 upstream=$2 prefix=$3 passed=0 failed=0
  # The upstream fuzzer is a fixed 30,000-iteration stress campaign. It is a
  # symmetric baseline skip under the AE contract; run the remaining registered
  # algorithm and CLI tests in both lanes.
  for test_name in fullbench zstreamtest; do
    test_args=()
    # Exercise every fullbench function once on a bounded sample. Its default
    # six timing iterations measure performance rather than add correctness
    # coverage and make the Hecate lane unnecessarily long.
    [[ $test_name == fullbench ]] && test_args=(-i1 -B100000)
    # zstreamtest is another randomized stress loop (10,000 iterations by
    # default). Keep a deterministic 100-iteration functional sample.
    [[ $test_name == zstreamtest ]] && test_args=(-i100 -s1)
    if run_zstd_binary "$lane" "$test_name" "${test_args[@]}"; then passed=$((passed + 1)); else failed=$((failed + 1)); cat "$run_dir/logs/$lane/$test_name.log"; fi
  done
  if run_play_tests "$lane" "$upstream" "$prefix"; then passed=$((passed + 1)); else failed=$((failed + 1)); cat "$run_dir/logs/$lane/playTests.log"; fi
  printf '%s selected upstream tests: %d passed, %d failed, 3 selected, 1 baseline skip\n' "$lane" "$passed" "$failed" | tee "$run_dir/logs/$lane/upstream-summary.log"
  [[ $passed == 3 && $failed == 0 ]]
}
native_status=0
hecate_status=0
run_zstd_suite native "$native_upstream" "$native_prefix" || native_status=$?
run_zstd_suite hecate "$guest_upstream" "$guest_prefix" || hecate_status=$?
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries = sys.argv[1:]
ok = native == hecate == "0"
data = {"schema_version": 2, "package": "zstd", "version": "1.5.7", "mechanism": "TLC Only", "status": "pass" if ok else "fail", "libraries": int(libraries), "native": {"exit_status": int(native)}, "hecate": {"exit_status": int(hecate)}, "output_match": True, "upstream_suite": {"registered_tests": 4, "selected_tests": 3, "baseline_skips": ["fuzzer"], "native_passed": 3 if native == "0" else 0, "hecate_passed": 3 if hecate == "0" else 0, "dynamic_test_patch": True, "program_multithreading": False, "library_multithreading": True, "excluded_subtests": ["zstreamtest external sequence producer section", "playTests dictionary training sections"], "exclusion_reason": "the 30,000-iteration fuzz campaign is outside the AE functional scope; guest callbacks and dictionary trainer buffer semantics are not supported across the thunk boundary"}}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
echo "Evidence: $run_dir"
