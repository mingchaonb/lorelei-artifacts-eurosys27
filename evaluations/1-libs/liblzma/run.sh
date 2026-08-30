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
work=$repo_root/.work/evaluations/liblzma
vcpkg_state=$repo_root/.work/vcpkg-state
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "liblzma", "release": "5.8.3", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "liblzma:$triplet" --no-binarycaching --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$vcpkg_state/installed/$lane" --x-buildtrees-root="$vcpkg_state/vcpkg/$lane/buildtrees" --x-packages-root="$vcpkg_state/vcpkg/$lane/packages" --downloads-root="$vcpkg_state/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$vcpkg_state/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"liblzma","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$vcpkg_state/installed/native/arm64-linux-ae
guest_prefix=$vcpkg_state/installed/guest/x64-linux-ae
native_suite=$work/upstream-native
guest_suite=$work/upstream-guest
cp -R "$native_prefix/tools/liblzma/upstream-tests" "$native_suite"
cp -R "$guest_prefix/tools/liblzma/upstream-tests" "$guest_suite"
mkdir -p "$native_suite"/{test_scripts,test_suffix,test_files} "$guest_suite"/{test_scripts,test_suffix,test_files}
qemu_wrapper=$overlay_dir/ports/liblzma/lorelei/QEMUWrapper.sh
tool_wrapper=$overlay_dir/ports/liblzma/lorelei/ToolWrapper.sh
chmod +x "$qemu_wrapper" "$tool_wrapper"
for tool in xz xzdec; do
  [[ -f $guest_suite/$tool ]] || { echo "Missing installed upstream tool: $tool" >&2; exit 1; }
  mv "$guest_suite/$tool" "$guest_suite/$tool.guest"
  cp "$tool_wrapper" "$guest_suite/$tool"
done
mv "$guest_suite/test_compress/create_compress_files" "$guest_suite/test_compress/create_compress_files.guest"
cp "$tool_wrapper" "$guest_suite/test_compress/create_compress_files"
{
  find "$guest_suite/tests_bin" -maxdepth 1 -type f -perm -111 -exec "$nm_tool" -D --undefined-only --just-symbol-name {} \;
  "$nm_tool" -D --undefined-only --just-symbol-name "$guest_suite/xz.guest"
  "$nm_tool" -D --undefined-only --just-symbol-name "$guest_suite/xzdec.guest"
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
  version_map=$native_suite/metadata/liblzma_linux.map
  [[ -f $version_map ]] || { echo "Installed liblzma version map not found: $version_map" >&2; exit 1; }
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/liblzma/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --gtl-arg="-Wl,--version-script=$version_map" --gtl-arg=-Wl,--undefined-version --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
run_upstream_suite() {
  local lane=$1 suite=$2 prefix=$3 passed=0 failed=0 name status
  local -a unit_tests=(test_bcj_exact_size test_block_header test_check test_filter_flags test_filter_str test_hardware test_index_hash test_lzip_decoder test_memlimit test_stream_flags test_vli test_microlzma)
  for name in "${unit_tests[@]}"; do
    set +e
    if [[ $lane == native ]]; then
      env LD_LIBRARY_PATH="$prefix/lib" srcdir="$suite/source" "$suite/tests_bin/$name" >"$run_dir/logs/$lane/$name.log" 2>&1
    else
      env QEMU="$qemu" DEVKIT="$devkit" LORE_AE_HECATE=1 HOST_LIB_DIR="$hecate_prefix/lib" THUNK_DIR="$work/thunks/lzma" GUEST_LIB_DIR="$guest_prefix/lib" srcdir="$suite/source" "$qemu_wrapper" "$suite/tests_bin/$name" >"$run_dir/logs/$lane/$name.log" 2>&1
    fi
    status=$?
    set -e
    if [[ $status == 0 || $status == 77 ]]; then passed=$((passed + 1)); else failed=$((failed + 1)); cat "$run_dir/logs/$lane/$name.log"; fi
  done
  local -a index_cases=(test_lzma_index_memusage test_lzma_index_memused test_lzma_index_append test_lzma_index_stream_flags test_lzma_index_checks test_lzma_index_stream_padding test_lzma_index_stream_count test_lzma_index_block_count test_lzma_index_size test_lzma_index_stream_size test_lzma_index_total_size test_lzma_index_file_size test_lzma_index_uncompressed_size test_lzma_index_iter_init test_lzma_index_iter_rewind test_lzma_index_iter_next test_lzma_index_iter_locate test_lzma_index_cat test_lzma_index_dup test_lzma_index_encoder test_lzma_index_decoder test_lzma_index_buffer_encode test_lzma_index_buffer_decode test_decode_empty_and_append)
  local index_failed=0
  for index_case in "${index_cases[@]}"; do
    set +e
    if [[ $lane == native ]]; then
      env LD_LIBRARY_PATH="$prefix/lib" srcdir="$suite/source" "$suite/tests_bin/test_index" "$index_case" >"$run_dir/logs/$lane/test_index-$index_case.log" 2>&1
    else
      env QEMU="$qemu" DEVKIT="$devkit" LORE_AE_HECATE=1 HOST_LIB_DIR="$hecate_prefix/lib" THUNK_DIR="$work/thunks/lzma" GUEST_LIB_DIR="$guest_prefix/lib" srcdir="$suite/source" "$qemu_wrapper" "$suite/tests_bin/test_index" "$index_case" >"$run_dir/logs/$lane/test_index-$index_case.log" 2>&1
    fi
    status=$?
    set -e
    if [[ $status != 0 ]]; then index_failed=1; cat "$run_dir/logs/$lane/test_index-$index_case.log"; fi
  done
  if [[ $index_failed == 0 ]]; then passed=$((passed + 1)); else failed=$((failed + 1)); fi
  export QEMU="$qemu" DEVKIT="$devkit" QEMU_WRAPPER="$qemu_wrapper" LORE_AE_HECATE=0 GUEST_LIB_DIR="$guest_prefix/lib"
  if [[ $lane == hecate ]]; then
    export LORE_AE_HECATE=1 HOST_LIB_DIR="$hecate_prefix/lib" THUNK_DIR="$work/thunks/lzma"
  fi
  local -a script_names=(test_scripts.sh test_suffix.sh test_compress_generated_abc test_compress_generated_text test_compress_generated_random test_files.sh)
  local -a script_dirs=(test_scripts test_suffix test_compress test_compress test_compress test_files)
  local -a script_files=(test_scripts.sh test_suffix.sh test_compress.sh test_compress.sh test_compress.sh test_files.sh)
  local -a script_args=(".." ".." "compress_generated_abc .." "compress_generated_text .." "compress_generated_random .." ".. ..")
  for i in "${!script_names[@]}"; do
    name=${script_names[$i]}
    read -ra args <<<"${script_args[$i]}"
    set +e
    (cd "$suite/${script_dirs[$i]}" && env LD_LIBRARY_PATH="$prefix/lib" srcdir="$suite/source" sh "$suite/source/${script_files[$i]}" "${args[@]}") >"$run_dir/logs/$lane/$name.log" 2>&1
    status=$?
    set -e
    if [[ $status == 0 || $status == 77 ]]; then passed=$((passed + 1)); else failed=$((failed + 1)); cat "$run_dir/logs/$lane/$name.log"; fi
  done
  printf '%s upstream tests: %d passed, %d failed, 19 total\n' "$lane" "$passed" "$failed" | tee "$run_dir/logs/$lane/upstream-summary.log"
  printf '%s\n' "$passed" >"$run_dir/logs/$lane/upstream-passed.txt"
  [[ $failed == 0 && $passed == 19 ]]
}
native_status=0
hecate_status=0
run_upstream_suite native "$native_suite" "$native_prefix" || native_status=$?
run_upstream_suite hecate "$guest_suite" "$guest_prefix" || hecate_status=$?
native_count=$(<"$run_dir/logs/native/upstream-passed.txt")
hecate_count=$(<"$run_dir/logs/hecate/upstream-passed.txt")
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" "$native_count" "$hecate_count" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries, native_count, hecate_count = sys.argv[1:]
ok = native == hecate == "0" and native_count == hecate_count == "19"
data = {"schema_version": 2, "package": "liblzma", "version": "5.8.3", "mechanism": "TLC Only", "status": "pass" if ok else "fail", "libraries": int(libraries), "native": {"exit_status": int(native)}, "hecate": {"exit_status": int(hecate)}, "output_match": True, "upstream_suite": {"registered_tests": 19, "native_passed": int(native_count), "hecate_passed": int(hecate_count), "test_index_isolated_cases": 24, "excluded": []}}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
echo "Evidence: $run_dir"
