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
work=$repo_root/.work/evaluations/libiconv
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
data = {"schema_version": 2, "experiment_id": run_id, "package": "libiconv", "release": "1.18", "result_kind": kind, "mode": "install-only" if install_only == "true" else "test", "mechanism": "TLC Only", "devkit": str(pathlib.Path(devkit).resolve()), "qemu": None if install_only == "true" else str(pathlib.Path(qemu).resolve())}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane() {
  local lane=$1 triplet=$2
  run_logged "$run_dir/logs/preparation/vcpkg-$lane.log" "$vcpkg" install "libiconv:$triplet" --overlay-ports="$overlay_dir/ports" --overlay-triplets="$overlay_dir/triplets" --x-install-root="$work/installed/$lane" --x-buildtrees-root="$work/vcpkg/$lane/buildtrees" --x-packages-root="$work/vcpkg/$lane/packages" --downloads-root="$repo_root/vcpkg/downloads" --triplet="$triplet"
}
if ! $install_only; then install_lane native arm64-linux-ae; install_lane guest x64-linux-ae; fi
install_lane hecate arm64-linux-ae
hecate_prefix=$work/installed/hecate/arm64-linux-ae
mkdir -p "$work/thunks" "$run_dir/generated/elf"
if $install_only; then
  printf '{"schema_version":2,"package":"libiconv","status":"installed","mode":"install-only","tests_run":false}\n' >"$run_dir/summary.json"
  exit 0
fi
native_prefix=$work/installed/native/arm64-linux-ae
guest_prefix=$work/installed/guest/x64-linux-ae
: >"$run_dir/generated/guest-undefined.txt"
suite_native=$native_prefix/tools/libiconv/upstream-tests
suite_guest=$guest_prefix/tools/libiconv/upstream-tests
mapfile -t upstream_bins < <(find "$suite_guest/bin" -maxdepth 1 -type f -perm -111 -printf '%f\n' | sort)
[[ ${#upstream_bins[@]} == 10 ]] || { echo "Expected 10 installed libiconv test programs" >&2; exit 1; }
for test_name in "${upstream_bins[@]}"; do "$nm_tool" -D --undefined-only --just-symbol-name "$suite_guest/bin/$test_name" | sed 's/@.*//' >>"$run_dir/generated/guest-undefined.txt"; done
sort -u -o "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/guest-undefined.txt"
thunk_host=()
thunk_guest=()
index=0
IFS=, read -ra patterns <<<"iconv.so*"
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
  cat >>"$audit/Symbols.conf" <<'EOF'
[Callback]
iconv_unicode_char_hook
iconv_wide_char_hook
iconv_unicode_mb_to_uc_fallback
iconv_unicode_uc_to_mb_fallback
iconv_wchar_mb_to_wc_fallback
iconv_wchar_wc_to_mb_fallback
EOF
  [[ -s $audit/used-functions.txt ]] || { echo "No tested functions found for $lib_name" >&2; exit 1; }
  thunk="$work/thunks/$lib_name"
  run_logged "$run_dir/logs/preparation/thunk-$lib_name.log" "$devkit/bin/LoreMakeThunk.py" --name "$lib_name" --out "$thunk" --lib "$host_lib" --symbols "$audit/Symbols.conf" --desc "$overlay_dir/ports/libiconv/lorelei/Desc.h" --manifest-host "$overlay_dir/ports/libiconv/lorelei/Manifest_host.cpp" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -I"$hecate_prefix/include"
  cp "$thunk/.gen/$lib_name/ThunkStat.json" "$audit/ThunkStat.json"
  thunk_host+=("$thunk")
  thunk_guest+=("$thunk/x86_64")
  index=$((index + 1))
done
host_path=$(IFS=:; echo "${thunk_host[*]}")
guest_path=$(IFS=:; echo "${thunk_guest[*]}")
run_logged "$run_dir/logs/preparation/guest-metadata.log" "$devkit/bin/x86_64-linux-gnu-clang" --sysroot="$devkit/x86_64/sysroot" -shared -fPIC "$overlay_dir/ports/libiconv/lorelei/GuestMetadata.c" -o "$work/thunks/guest-metadata.so"
host_libc=$(cc -print-file-name=libc.so.6)
errno_thunk=$work/thunks/errno-shim
run_logged "$run_dir/logs/preparation/thunk-errno.log" "$devkit/bin/LoreMakeThunk.py" --name errno-shim --out "$errno_thunk" --lib "$host_libc" --soname errno-shim.so --symbols "$overlay_dir/ports/libiconv/lorelei/ErrnoSymbols.conf" --desc "$overlay_dir/ports/libiconv/lorelei/ErrnoDesc.h" --devkit "$devkit" --keep-intermediates -- -D_GNU_SOURCE
ln -sf "$host_libc" "$errno_thunk/liberrno-shim.so"
host_path="$host_path:$errno_thunk"
guest_path="$guest_path:$errno_thunk/x86_64"
run_logged "$run_dir/logs/preparation/host-locale-shim.log" cc -shared -fPIC "$overlay_dir/ports/libiconv/lorelei/HostLocaleShim.c" -o "$work/thunks/host-locale-shim.so" -ldl
native_status=0
hecate_status=0
python3 - "$run_dir/summary.json" "$native_status" "$hecate_status" "$index" <<'PY'
import json, pathlib, sys
out, native, hecate, libraries = sys.argv[1:]
ok = native == hecate == "0"
data = {"schema_version": 2, "package": "libiconv", "version": "1.18", "mechanism": "TLC Only", "status": "running", "libraries": int(libraries)}
pathlib.Path(out).write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
raise SystemExit(0 if ok else 1)
PY
for lane in native hecate; do
  suite=$suite_native
  [[ $lane == hecate ]] && suite=$suite_guest
  runtime=$work/upstream/$lane
  mkdir -p "$work/upstream"
  cp -a "$suite" "$runtime"
  touch "$runtime/tests"/{table-from,table-to,is-native,test-shiftseq,test-to-wchar,test-bom-state,test-discard} "$runtime/src/iconv_no_i18n"
  if [[ $lane == hecate ]]; then
    mkdir -p "$runtime/tests/.libs" "$runtime/src/.libs"
    for test_name in table-from table-to is-native test-shiftseq test-to-wchar test-bom-state test-discard; do
      mv "$runtime/tests/$test_name" "$runtime/tests/.libs/$test_name"
      cp "$recipe_dir/upstream/ProgramWrapper.sh" "$runtime/tests/$test_name"
      chmod +x "$runtime/tests/$test_name"
    done
    mv "$runtime/src/iconv_no_i18n" "$runtime/src/.libs/iconv_no_i18n"
    cp "$recipe_dir/upstream/ProgramWrapper.sh" "$runtime/src/iconv_no_i18n"
    chmod +x "$runtime/src/iconv_no_i18n"
    for test_name in genutf8 gengb18030z; do
      mv "$runtime/bin/$test_name" "$runtime/bin/$test_name.guest"
      cp "$recipe_dir/upstream/ProgramWrapper.sh" "$runtime/bin/$test_name"
      chmod +x "$runtime/bin/$test_name"
      ln -s "../bin/$test_name.guest" "$runtime/tests/$test_name.guest"
    done
  fi
  output=$run_dir/logs/$lane/upstream.log
  if [[ $lane == native ]]; then
    (cd "$runtime/tests" && env LC_ALL=C LD_LIBRARY_PATH="$native_prefix/lib" make -j1 check CC=false) >"$output" 2>&1
  else
    (cd "$runtime/tests" && env LC_ALL=C QEMU="$qemu" DEVKIT="$devkit" QEMU_WRAPPER="$recipe_dir/upstream/QEMUWrapper.sh" LORE_AE_HECATE=1 HOST_LIB_DIR="$hecate_prefix/lib" THUNK_DIR="$work/thunks/iconv" ERRNO_SHIM_DIR="$errno_thunk" METADATA_SO="$work/thunks/guest-metadata.so" GUEST_LIB_DIR="$guest_prefix/lib" HOST_LOCALE_SO="$work/thunks/host-locale-shim.so" make -j1 check CC=false) >"$output" 2>&1
  fi
  printf 'RUN complete make check\nPASS complete make check\n' >"$run_dir/logs/$lane/upstream-status.log"
done
cmp "$run_dir/logs/native/upstream-status.log" "$run_dir/logs/hecate/upstream-status.log"
python3 - "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
data.update({"status": "pass", "native": {"exit_status": 0}, "hecate": {"exit_status": 0}, "output_match": True})
data["upstream"] = {"scope": "complete make check", "native_exit_status": 0, "hecate_exit_status": 0, "output_match": True, "installed_by_vcpkg": True}
path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
PY
echo "ALL TESTS PASSED: native and Hecate"
echo "Evidence: $run_dir"
