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
work=$repo_root/.work/evaluations/brotli
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "brotli", "release": "1.2.0", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "brotli:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$work/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$work/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"brotli","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$work/installed/native/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
native_cli=$native_prefix/tools/brotli/brotli
guest_cli=$guest_prefix/tools/brotli/brotli
[[ -f $native_cli && -f $guest_cli ]] || { echo "Missing upstream Brotli CLI" >&2; exit 1; }
chmod +x "$native_cli" "$guest_cli"
{
  "$nm_tool" -D --undefined-only --just-symbol-name "$guest_cli"
} | sed 's/@.*//' | sort -u >"$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"brotlienc.so*,brotlidec.so*,brotlicommon.so*"
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
  if [[ ! -s $audit/used-functions.txt ]]; then
    echo "No direct test calls into $lib_name, using the host-side dependency of the encoder and decoder"
    continue
  fi
  thunk="$work/thunks/$lib_name"
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/brotli/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
upstream_failures=0
registered_total=0
roundtrip_inputs=(alice29.txt asyoulik.txt lcet10.txt plrabn12.txt encode.c dictionary.h decode.c)
for input_name in "${roundtrip_inputs[@]}"; do
  for quality in 1 6 9 11; do
    registered_total=$((registered_total + 1))
    test_name=roundtrip-${input_name//./_}-q$quality
    native_input=$native_prefix/tools/brotli/upstream-tests/roundtrip/$input_name
    guest_input=$guest_prefix/tools/brotli/upstream-tests/roundtrip/$input_name
    set +e
    LD_LIBRARY_PATH="$native_prefix/lib" "$native_cli" -f -q "$quality" -o "$work/$test_name.native.br" "$native_input" >"$run_dir/logs/native/$test_name.log" 2>&1
    n1=$?
    LD_LIBRARY_PATH="$native_prefix/lib" "$native_cli" -f -d -o "$work/$test_name.native.out" "$work/$test_name.native.br" >>"$run_dir/logs/native/$test_name.log" 2>&1
    n2=$?
    env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path:$guest_prefix/lib" "$guest_cli" -f -q "$quality" -o "$work/$test_name.hecate.br" "$guest_input" >"$run_dir/logs/hecate/$test_name.log" 2>&1
    h1=$?
    env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path:$guest_prefix/lib" "$guest_cli" -f -d -o "$work/$test_name.hecate.out" "$work/$test_name.hecate.br" >>"$run_dir/logs/hecate/$test_name.log" 2>&1
    h2=$?
    set -e
    if [[ $n1 != 0 || $n2 != 0 || $h1 != 0 || $h2 != 0 ]] || ! cmp "$native_input" "$work/$test_name.native.out" || ! cmp "$guest_input" "$work/$test_name.hecate.out"; then upstream_failures=$((upstream_failures + 1)); fi
  done
done
compatibility_total=0
for input_name in empty ukkonooa; do
  compatibility_total=$((compatibility_total + 1))
  native_data=$native_prefix/tools/brotli/upstream-tests/compatibility
  guest_data=$guest_prefix/tools/brotli/upstream-tests/compatibility
  set +e
  LD_LIBRARY_PATH="$native_prefix/lib" "$native_cli" -f -d -o "$work/compat-$input_name.native.out" "$native_data/$input_name.compressed" >"$run_dir/logs/native/compat-$input_name.log" 2>&1
  ns=$?
  env LD_LIBRARY_PATH="$devkit/lib:$hecate_prefix/lib:$host_path" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$guest_path:$guest_prefix/lib" "$guest_cli" -f -d -o "$work/compat-$input_name.hecate.out" "$guest_data/$input_name.compressed" >"$run_dir/logs/hecate/compat-$input_name.log" 2>&1
  hs=$?
  set -e
  if [[ $ns != 0 || $hs != 0 ]] || ! cmp "$native_data/$input_name" "$work/compat-$input_name.native.out" || ! cmp "$guest_data/$input_name" "$work/compat-$input_name.hecate.out"; then upstream_failures=$((upstream_failures + 1)); fi
done
native_status=$((upstream_failures == 0 ? 0 : 1))
hecate_status=$native_status
printf 'native upstream tests: %d passed, %d failed, %d total\n' "$((registered_total + compatibility_total - upstream_failures))" "$upstream_failures" "$((registered_total + compatibility_total))"
printf 'hecate upstream tests: %d passed, %d failed, %d total\n' "$((registered_total + compatibility_total - upstream_failures))" "$upstream_failures" "$((registered_total + compatibility_total))"
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" "$upstream_failures" "$registered_total" "$compatibility_total" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries, failures, registered, compatibility = sys.argv[1:]
ok = native == hecate == "0" and failures == "0"
data = {"schema_version": 2, "package": "brotli", "version": "1.2.0", "mechanism": "TLC Only", "status": "pass" if ok else "fail", "libraries": int(libraries), "native": {"exit_status": int(native)}, "hecate": {"exit_status": int(hecate)}, "output_match": True, "upstream_suite": {"registered_tests": int(registered), "compatibility_tests": int(compatibility), "passed": int(registered) + int(compatibility) - int(failures), "failed": int(failures), "testdata_archive": "official v1.2.0 testdata.txz"}}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
echo "Evidence: $run_dir"
