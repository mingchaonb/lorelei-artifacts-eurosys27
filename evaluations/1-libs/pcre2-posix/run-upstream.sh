#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
source_repo=${PCRE2_SOURCE:-$(dirname "$repo_root")/ae-libs/pcre2}
expected_commit=b2bd4254b379b9d7dc9a3dda060a7e27009ccdff
reference=false
positional=()
for arg in "$@"; do
  case "$arg" in
    --reference) reference=true ;;
    -h|--help) echo "Usage: $0 [--reference] /path/to/lorelei-devkit"; exit 0 ;;
    --*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) positional+=("$arg") ;;
  esac
done
[[ ${#positional[@]} == 1 ]] || { echo "Expected one devkit path" >&2; exit 2; }
devkit=$(realpath "${positional[0]}")
qemu=$(realpath -m "${QEMU:-$devkit/bin/qemu-x86_64}")
[[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
[[ $(git -C "$source_repo" rev-parse 'pcre2-10.46^{}') == "$expected_commit" ]] || { echo "PCRE2 source is not 10.46" >&2; exit 2; }
work=$repo_root/.work/evaluations/pcre2-posix-upstream
results_root=$recipe_dir/upstream-results
$reference && results_root=$recipe_dir/upstream-reference-results
run_dir=$results_root/$(date -u +%Y%m%dT%H%M%SZ)
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then echo "Refusing unmarked work directory" >&2; exit 2; fi
if [[ -e $work ]]; then cmake -E remove_directory "$work"; fi
mkdir -p "$work" "$run_dir"/{generated,logs/native,logs/hecate,logs/preparation}
touch "$work/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1
git -C "$source_repo" archive "$expected_commit" | tar -x -C "$work"
args=(--enable-shared --disable-static --disable-jit --disable-pcre2-16 --disable-pcre2-32 --disable-pcre2grep-libz --disable-pcre2grep-libbz2 --disable-pcre2test-libreadline)
mkdir "$work/native" "$work/guest"
(cd "$work/native" && ../configure "${args[@]}") >"$run_dir/logs/preparation/native-configure.log" 2>&1
make -C "$work/native" -j"$(nproc)" >"$run_dir/logs/preparation/native-build.log" 2>&1
(cd "$work/guest" && CC="$devkit/bin/x86_64-linux-gnu-clang" CFLAGS="--sysroot=$devkit/x86_64/sysroot -O2" LDFLAGS="--sysroot=$devkit/x86_64/sysroot" ../configure --host=x86_64-linux-gnu "${args[@]}") >"$run_dir/logs/preparation/guest-configure.log" 2>&1
make -C "$work/guest" -j"$(nproc)" >"$run_dir/logs/preparation/guest-build.log" 2>&1
native_test=$work/native/.libs/pcre2posix_test
guest_test=$work/guest/.libs/pcre2posix_test
host_lib=$work/native/.libs/libpcre2-posix.so.3.0.6
nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || command -v nm)
"$nm_tool" -D --undefined-only --just-symbol-name "$guest_test" | sed 's/@.*//' | sort -u >"$run_dir/generated/guest-undefined.txt"
"$nm_tool" -D --defined-only --format=posix "$host_lib" | awk '$2 == "T" || $2 == "W" {n=$1; sub(/@.*/, "", n); print n}' | sort -u >"$run_dir/generated/host-functions.txt"
comm -12 "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/host-functions.txt" >"$run_dir/generated/functions.txt"
{ echo '[Function]'; cat "$run_dir/generated/functions.txt"; } >"$run_dir/generated/Symbols.conf"
"$devkit/bin/LoreMakeThunk.py" --name pcre2-posix --out "$work/thunk" --lib "$host_lib" --symbols "$run_dir/generated/Symbols.conf" --desc "$repo_root/vcpkg-overlay/ports/pcre2-posix/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -I"$work/src" >"$run_dir/logs/preparation/thunk.log" 2>&1
cp "$work/thunk/.gen/pcre2-posix/ThunkStat.json" "$run_dir/generated/ThunkStat.json"
env LD_LIBRARY_PATH="$work/native/.libs" "$native_test" >"$run_dir/logs/native/upstream.log" 2>&1
env LD_LIBRARY_PATH="$devkit/lib:$work/native/.libs:$work/thunk" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64:$work/guest/.libs" "$guest_test" >"$run_dir/logs/hecate/upstream.log" 2>&1
cmp "$run_dir/logs/native/upstream.log" "$run_dir/logs/hecate/upstream.log"
python3 - "$run_dir/summary.json" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({"schema_version": 2, "package": "pcre2-posix", "version": "10.46", "suite": "upstream pcre2posix_test", "status": "pass", "tests": 1, "native": {"exit_status": 0}, "hecate": {"exit_status": 0}, "output_match": True, "jit": False, "pure_qemu_run": False}, indent=2, sort_keys=True) + "\n")
PY
echo "Evidence: $run_dir"
