#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == --resolve-qemu ]]; then
    devkit=$2
    repo_root=$3
    candidate=${QEMU:-$repo_root/../qemu-ae/build/qemu-x86_64}
    [[ -x $candidate ]] || { echo "Patched QEMU not found: $candidate" >&2; exit 2; }
    realpath "$candidate"
    exit 0
fi

if [[ ${1:-} == --launch-hecate ]]; then
    shift
    exec env LD_LIBRARY_PATH="${HECATE_HOST_LIBRARY_PATH:?}" "${HECATE_QEMU:?}" \
        -L "${HECATE_GUEST_SYSROOT:?}" -E LD_BIND_NOW=1 \
        -E "LD_LIBRARY_PATH=${HECATE_GUEST_LIBRARY_PATH:?}" "$@"
fi

target=$1
repo_root=$2
work=$3
run_dir=$4
devkit=$5
qemu=$6
host_prefix=$7
guest_prefix=$8
host_runtime=$9
guest_runtime=${10}
verbose=${11}

runner=$(realpath "${BASH_SOURCE[0]}")
driver=$(dirname "$runner")/audio-signal-ctest.py
upstream=$work/upstream
mkdir -p "$upstream" "$run_dir/logs/upstream"/{preparation,native,hecate} "$run_dir/generated/upstream"

run_logged() {
    local log=$1 status
    shift
    printf '  $'
    printf ' %q' "$@"
    printf '\n'
    if [[ $verbose != true ]]; then "$@" >"$log" 2>&1; return; fi
    set +e
    "$@" 2>&1 | tee "$log"
    status=${PIPESTATUS[0]}
    set -e
    return "$status"
}

installed_test_tree() {
    local lane=$1 kind=$2 prefix
    [[ $lane == host ]] && prefix=$host_prefix || prefix=$guest_prefix
    local tree=$prefix/tools/$target/upstream-tests/$kind
    [[ -d $tree ]] || { echo "Missing installed upstream $kind tree for $target/$lane: $tree" >&2; exit 1; }
    realpath "$tree"
}

export HECATE_QEMU=$qemu
export HECATE_GUEST_SYSROOT=$devkit/x86_64/sysroot
export HECATE_HOST_LIBRARY_PATH=$host_runtime
export HECATE_GUEST_LIBRARY_PATH=$guest_runtime
export HECATE_TEST_RUNNER="$runner --launch-hecate"

run_ctest_pair() {
    local native_build=$1 native_source=$2 guest_build=$3 guest_source=$4
    shift 4
    run_logged "$run_dir/logs/upstream/native/upstream.log" \
        env -u LIBAEC_TEST_RUNNER -u SNDFILE_TEST_RUNNER LD_LIBRARY_PATH="$host_prefix/lib" \
        python3 "$driver" "$native_build" "$native_source" native
    run_logged "$run_dir/logs/upstream/hecate/upstream.log" \
        python3 "$driver" "$guest_build" "$guest_source" hecate "$@"
}

extra_thunk() {
    local name=$1 library=$2 symbols=$3 desc=$4 aliases=$5
    local out=$upstream/thunks/$name host_library
    host_library=$(find "$host_prefix/lib" -maxdepth 1 -type f -name "$library" ! -type l | sort | head -1)
    [[ -n $host_library ]] || { echo "Missing host library for $name" >&2; exit 1; }
    local alias_args=() alias
    IFS=',' read -r -a alias_list <<< "$aliases"
    for alias in "${alias_list[@]}"; do alias_args+=(--gtl-alias "$alias"); done
    run_logged "$run_dir/logs/upstream/preparation/thunk-$name.log" \
        "$devkit/bin/LoreMakeThunk.py" --name "$name" --out "$out" --lib "$host_library" \
        --symbols "$symbols" --desc "$desc" "${alias_args[@]}" \
        --devkit "$devkit" --keep-intermediates -- -I"$host_prefix/include"
    HECATE_HOST_LIBRARY_PATH="$HECATE_HOST_LIBRARY_PATH:$out"
    HECATE_GUEST_LIBRARY_PATH="$HECATE_GUEST_LIBRARY_PATH:$out/x86_64"
    export HECATE_HOST_LIBRARY_PATH HECATE_GUEST_LIBRARY_PATH
}

case $target in
    fftw3)
        native_build=$(installed_test_tree host build); guest_build=$(installed_test_tree guest build)
        : >"$run_dir/logs/upstream/native/upstream.log"
        : >"$run_dir/logs/upstream/hecate/upstream.log"
        for case_name in 32x64 ib256; do
            echo "RUN $case_name" >>"$run_dir/logs/upstream/native/upstream.log"
            env LD_LIBRARY_PATH="$host_prefix/lib" "$native_build/bench" -s "$case_name" >>"$run_dir/logs/upstream/native/upstream.log" 2>&1
            echo "PASS $case_name" >>"$run_dir/logs/upstream/native/upstream.log"
            echo "RUN $case_name" >>"$run_dir/logs/upstream/hecate/upstream.log"
            "$runner" --launch-hecate "$guest_build/bench" -s "$case_name" >>"$run_dir/logs/upstream/hecate/upstream.log" 2>&1
            echo "PASS $case_name" >>"$run_dir/logs/upstream/hecate/upstream.log"
        done
        native_count=2; hecate_count=2; native_internal=0
        ;;
    libaec)
        native_build=$(installed_test_tree host build); native_source=$(installed_test_tree host source)
        guest_build=$(installed_test_tree guest build); guest_source=$(installed_test_tree guest source)
        export LIBAEC_TEST_RUNNER="$runner --launch-hecate"
        run_ctest_pair "$native_build" "$native_source" "$guest_build" "$guest_source"
        native_count=7; hecate_count=7; native_internal=0
        ;;
    libcerf)
        native_build=$(installed_test_tree host build); native_source=$(installed_test_tree host source)
        guest_build=$(installed_test_tree guest build); guest_source=$(installed_test_tree guest source)
        run_ctest_pair "$native_build" "$native_source" "$guest_build" "$guest_source"
        native_count=9; hecate_count=9; native_internal=0
        ;;
    libogg)
        native_build=$(installed_test_tree host build); guest_build=$(installed_test_tree guest build)
        : >"$run_dir/logs/upstream/native/upstream.log"
        : >"$run_dir/logs/upstream/hecate/upstream.log"
        for name in test_bitwise test_framing; do
            echo "RUN $name" >>"$run_dir/logs/upstream/native/upstream.log"
            env LD_LIBRARY_PATH="$host_prefix/lib" "$native_build/$name" >>"$run_dir/logs/upstream/native/upstream.log" 2>&1
            echo "PASS $name" >>"$run_dir/logs/upstream/native/upstream.log"
            echo "RUN $name" >>"$run_dir/logs/upstream/hecate/upstream.log"
            "$runner" --launch-hecate "$guest_build/$name" >>"$run_dir/logs/upstream/hecate/upstream.log" 2>&1
            echo "PASS $name" >>"$run_dir/logs/upstream/hecate/upstream.log"
        done
        native_count=2; hecate_count=2; native_internal=0
        ;;
    libsamplerate)
        extra_thunk fftw3 'libfftw3.so.*' "$repo_root/vcpkg-overlay/ports/fftw3/lorelei/Symbols.conf" "$repo_root/vcpkg-overlay/ports/fftw3/lorelei/Desc.h" 'libfftw3.so,libfftw3.so.3'
        native_build=$(installed_test_tree host build); native_source=$(installed_test_tree host source)
        guest_build=$(installed_test_tree guest build); guest_source=$(installed_test_tree guest source)
        run_ctest_pair "$native_build" "$native_source" "$guest_build" "$guest_source"
        native_count=13; hecate_count=13; native_internal=0
        ;;
    libsndfile)
        native_build=$(installed_test_tree host build); native_source=$(installed_test_tree host source)
        guest_build=$(installed_test_tree guest build); guest_source=$(installed_test_tree guest source)
        for rel in tests/stdin_test tests/stdout_test; do
            if [[ ! -e $guest_build/$rel.x64 ]]; then
                mv "$guest_build/$rel" "$guest_build/$rel.x64"
            fi
            printf '#!/usr/bin/env bash\nexec %q --launch-hecate %q "$@"\n' "$runner" "$guest_build/$rel.x64" >"$guest_build/$rel"
            chmod +x "$guest_build/$rel"
        done
        unset SNDFILE_TEST_RUNNER
        run_ctest_pair "$native_build" "$native_source" "$guest_build" "$guest_source"
        native_count=142; hecate_count=142; native_internal=0
        ;;
    soxr)
        native_build=$(installed_test_tree host build); native_source=$(installed_test_tree host source)
        guest_build=$(installed_test_tree guest build); guest_source=$(installed_test_tree guest source)
        for rel in examples/3-options-input-fn tests/vector-cmp; do
            if [[ ! -e $guest_build/$rel.x64 ]]; then
                mv "$guest_build/$rel" "$guest_build/$rel.x64"
            fi
            printf '#!/usr/bin/env bash\nexec %q --launch-hecate %q "$@"\n' "$runner" "$guest_build/$rel.x64" >"$guest_build/$rel"
            chmod +x "$guest_build/$rel"
        done
        run_ctest_pair "$native_build" "$native_source" "$guest_build" "$guest_source"
        native_count=9; hecate_count=9; native_internal=0
        ;;
    mpg123|libsyn123)
        native_build=$(installed_test_tree host build); guest_build=$(installed_test_tree guest build)
        if [[ $target == mpg123 ]]; then
            extra_thunk syn123 'libsyn123.so.*' "$repo_root/vcpkg-overlay/ports/libsyn123/lorelei/Symbols.conf" "$repo_root/vcpkg-overlay/ports/libsyn123/lorelei/Desc.h" 'libsyn123.so,libsyn123.so.0'
        fi
        if [[ $target == libsyn123 ]]; then
            run_logged "$run_dir/logs/upstream/native/upstream.log" env LD_LIBRARY_PATH="$host_prefix/lib" "$native_build/src/tests/.libs/resample_total"
            run_logged "$run_dir/logs/upstream/hecate/upstream.log" "$runner" --launch-hecate "$guest_build/src/tests/.libs/resample_total"
            native_count=1; hecate_count=1; native_internal=0
        else
            native_source=$(installed_test_tree host source)
            run_logged "$run_dir/logs/upstream/native/upstream.log" env LD_LIBRARY_PATH="$host_prefix/lib" bash -c '
                set -euo pipefail
                cd "$1"
                export srcdir="$2"
                unset MPG123_TEST_RUNNER
                for name in seek_whence.sh seek_accuracy.sh; do
                    echo "RUN $name"
                    "$srcdir/src/tests/$name"
                    echo "PASS $name"
                done
                for name in resample_total text textprint; do
                    echo "RUN $name"
                    "./src/tests/.libs/$name"
                    echo "PASS $name"
                done
                echo "RUN plain_id3.sh"
                "$srcdir/src/tests/plain_id3.sh"
                echo "PASS plain_id3.sh"
            ' _ "$native_build" "$native_source"
            guest_source=$(installed_test_tree guest source)
            run_logged "$run_dir/logs/upstream/hecate/upstream.log" bash -c '
                set -euo pipefail
                cd "$1"
                export srcdir="$2"
                export MPG123_TEST_RUNNER="$3 --launch-hecate"
                for name in seek_whence.sh seek_accuracy.sh; do
                    echo "RUN $name"
                    "$srcdir/src/tests/$name"
                    echo "PASS $name"
                done
                for name in resample_total text textprint; do
                    echo "RUN $name"
                    "$3" --launch-hecate "./src/tests/.libs/$name"
                    echo "PASS $name"
                done
                echo "RUN plain_id3.sh"
                "$srcdir/src/tests/plain_id3.sh"
                echo "PASS plain_id3.sh"
            ' _ "$guest_build" "$guest_source" "$runner"
            native_count=6; hecate_count=6; native_internal=0
        fi
        ;;
    libvorbis)
        native_build=$(installed_test_tree host build); native_source=$(installed_test_tree host source)
        guest_build=$(installed_test_tree guest build); guest_source=$(installed_test_tree guest source)
        run_ctest_pair "$native_build" "$native_source" "$guest_build" "$guest_source"
        native_count=528; hecate_count=528; native_internal=0
        ;;
    libvorbisfile)
        printf 'upstream_release=libvorbis-1.3.7\nregistered_libvorbisfile_tests=0\n' >"$run_dir/logs/upstream/native/upstream.log"
        cp "$run_dir/logs/upstream/native/upstream.log" "$run_dir/logs/upstream/hecate/upstream.log"
        native_count=0; hecate_count=0; native_internal=0
        ;;
    opus)
        native_build=$(installed_test_tree host build); native_source=$(installed_test_tree host source)
        guest_build=$(installed_test_tree guest build); guest_source=$(installed_test_tree guest source)
        run_logged "$run_dir/logs/upstream/native/upstream.log" env LD_LIBRARY_PATH="$host_prefix/lib" python3 "$driver" "$native_build" "$native_source" native
        run_logged "$run_dir/logs/upstream/hecate/upstream.log" bash -c 'for n in test_opus_decode test_opus_padding test_opus_api test_opus_encode; do echo "RUN $n"; "$0" --launch-hecate "$1/$n"; echo "PASS $n"; done' "$runner" "$guest_build"
        native_count=4; hecate_count=4; native_internal=0
        ;;
    *) echo "Unknown audio upstream target: $target" >&2; exit 2 ;;
esac

python3 - "$run_dir/upstream-summary.json" "$target" "$native_count" "$hecate_count" "$native_internal" <<'PY'
import json
import pathlib
import sys

path, package, native, hecate, internal = sys.argv[1:]
pathlib.Path(path).write_text(json.dumps({
    "schema_version": 2,
    "package": package,
    "suite": "all runnable upstream tests in the evaluated configuration",
    "status": "pass",
    "native": {"passed": int(native)},
    "hecate": {"passed": int(hecate)},
    "native_only_internal": int(internal),
    "pure_qemu_run": False,
}, indent=2, sort_keys=True) + "\n")
PY
echo "ALL UPSTREAM TESTS PASSED: $target native=$native_count hecate=$hecate_count pure_qemu=false"
