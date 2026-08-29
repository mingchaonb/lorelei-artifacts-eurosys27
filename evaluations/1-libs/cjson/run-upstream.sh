#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
source_repo=${CJSON_SOURCE:-$(dirname "$repo_root")/ae-libs/cJSON}
expected_commit=c859b25da02955fef659d658b8f324b5cde87be3
devkit=
reference=false
verbose=false
positional=()
for arg in "$@"; do
  case "$arg" in
    --reference) reference=true ;;
    --verbose) verbose=true ;;
    -h|--help) echo "Usage: $0 [--reference] [--verbose] /path/to/lorelei-devkit"; exit 0 ;;
    --*) echo "Unknown option: $arg" >&2; exit 2 ;;
    *) positional+=("$arg") ;;
  esac
done
[[ ${#positional[@]} == 1 ]] || { echo "Expected one devkit path" >&2; exit 2; }
devkit=$(realpath "${positional[0]}")
qemu=$(realpath -m "${QEMU:-$devkit/bin/qemu-x86_64}")
[[ -x $qemu ]] || { echo "Patched QEMU not found: $qemu" >&2; exit 2; }
[[ $(git -C "$source_repo" rev-parse HEAD) == "$expected_commit" ]] || { echo "cJSON source is not v1.7.19" >&2; exit 2; }

work=$repo_root/.work/evaluations/cjson-upstream
results_root=$recipe_dir/upstream-results
$reference && results_root=$recipe_dir/upstream-reference-results
run_id=$(date -u +%Y%m%dT%H%M%SZ)
run_dir=$results_root/$run_id
if [[ -e $work && ! -f $work/.lorelei-evaluations-workspace ]]; then
  echo "Refusing unmarked work directory: $work" >&2
  exit 2
fi
if [[ -e $work ]]; then cmake -E remove_directory "$work"; fi
mkdir -p "$work" "$run_dir"/{generated,logs/native,logs/hecate,logs/preparation}
touch "$work/.lorelei-evaluations-workspace"
exec > >(tee "$run_dir/commands.log") 2>&1

run_logged() {
  local log=$1 status
  shift
  printf '  $'
  printf ' %q' "$@"
  printf '\n'
  if ! $verbose; then "$@" >"$log" 2>&1; return; fi
  set +e
  "$@" 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  set -e
  return "$status"
}

tests=(cJSON_test parse_examples parse_number parse_hex4 parse_string parse_array parse_object parse_value print_string print_number print_array print_object print_value misc_tests parse_with_opts compare_tests cjson_add readme_examples minify_tests)
git -C "$source_repo" archive "$expected_commit" | tar -x -C "$work"
common=(-G Ninja -DBUILD_SHARED_LIBS=ON -DENABLE_CJSON_TEST=ON -DENABLE_CJSON_UTILS=OFF -DENABLE_SANITIZERS=OFF -DENABLE_CUSTOM_COMPILER_FLAGS=OFF -DENABLE_TARGET_EXPORT=OFF)
run_logged "$run_dir/logs/preparation/native-configure.log" env CC=cc cmake -S "$work" -B "$work/native" "${common[@]}"
run_logged "$run_dir/logs/preparation/native-build.log" cmake --build "$work/native" -j"$(nproc)"
run_logged "$run_dir/logs/preparation/guest-configure.log" env CC="$devkit/bin/x86_64-linux-gnu-clang" cmake -S "$work" -B "$work/guest" "${common[@]}" -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64 -DCMAKE_SYSROOT="$devkit/x86_64/sysroot"
run_logged "$run_dir/logs/preparation/guest-build.log" cmake --build "$work/guest" -j"$(nproc)"

host_lib=$(readlink -f "$work/native/libcjson.so")
nm_tool=$(command -v llvm-nm-20 || command -v llvm-nm || command -v nm)
: >"$run_dir/generated/guest-undefined.txt"
for name in "${tests[@]}"; do
  if [[ $name == cJSON_test ]]; then bin=$work/guest/$name; else bin=$work/guest/tests/$name; fi
  "$nm_tool" -D --undefined-only --just-symbol-name "$bin" | sed 's/@.*//' >>"$run_dir/generated/guest-undefined.txt"
done
sort -u -o "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/guest-undefined.txt"
"$nm_tool" -D --defined-only --format=posix "$host_lib" | awk '$2 == "T" || $2 == "W" {n=$1; sub(/@.*/, "", n); print n}' | sort -u >"$run_dir/generated/host-functions.txt"
comm -12 "$run_dir/generated/guest-undefined.txt" "$run_dir/generated/host-functions.txt" >"$run_dir/generated/functions.txt"
{ echo '[Function]'; cat "$run_dir/generated/functions.txt"; } >"$run_dir/generated/Symbols.conf"
run_logged "$run_dir/logs/preparation/thunk.log" "$devkit/bin/LoreMakeThunk.py" --name cjson --out "$work/thunk" --lib "$host_lib" --symbols "$run_dir/generated/Symbols.conf" --desc "$repo_root/vcpkg-overlay/ports/cjson/lorelei/Desc.h" --gtl-alias "$(basename "$host_lib")" --devkit "$devkit" --keep-intermediates -- -I"$work"
cp "$work/thunk/.gen/cjson/ThunkStat.json" "$run_dir/generated/ThunkStat.json"

run_lane() {
  local lane=$1 build=$2 output=$run_dir/logs/$1/upstream.log
  : >"$output"
  for name in "${tests[@]}"; do
    if [[ $name == cJSON_test ]]; then dir=$work/$build; rel=./$name; else dir=$work/$build/tests; rel=./$name; fi
    echo "RUN $name" >>"$output"
    if [[ $lane == native ]]; then
      (cd "$dir" && env LD_LIBRARY_PATH="$work/native" "$rel") >>"$output" 2>&1
    else
      (cd "$dir" && env LD_LIBRARY_PATH="$devkit/lib:$work/native:$work/thunk" "$qemu" -L "$devkit/x86_64/sysroot" -E LD_BIND_NOW=1 -E "LD_LIBRARY_PATH=$devkit/x86_64/lib:$work/thunk/x86_64" "$rel") >>"$output" 2>&1
    fi
    echo "PASS $name" >>"$output"
  done
}
run_lane native native
run_lane hecate guest
sed -E 's/0x[0-9a-fA-F]+/<PTR>/g; s/[0-9]+ ms/<TIME> ms/g' "$run_dir/logs/native/upstream.log" >"$run_dir/logs/native/normalized.log"
sed -E 's/0x[0-9a-fA-F]+/<PTR>/g; s/[0-9]+ ms/<TIME> ms/g' "$run_dir/logs/hecate/upstream.log" >"$run_dir/logs/hecate/normalized.log"
cmp "$run_dir/logs/native/normalized.log" "$run_dir/logs/hecate/normalized.log"
python3 - "$run_dir/summary.json" "$(wc -l <"$run_dir/generated/functions.txt")" <<'PY'
import json, pathlib, sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({"schema_version": 2, "package": "cjson", "version": "1.7.19", "suite": "configured upstream core", "status": "pass", "tests": 19, "functions": int(sys.argv[2]), "native": {"exit_status": 0}, "hecate": {"exit_status": 0}, "output_match": True, "pure_qemu_run": False}, indent=2, sort_keys=True) + "\n")
PY
echo "Evidence: $run_dir"
