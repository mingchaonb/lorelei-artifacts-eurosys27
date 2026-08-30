#!/usr/bin/env bash
set -euo pipefail

recipe_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$recipe_dir/../../.." && pwd)
overlay_dir=$repo_root/vcpkg-overlay
state=$repo_root/.work/evaluations/breakdown-test
vcpkg=$repo_root/vcpkg/vcpkg
install_only=false
positional=()

while (($#)); do
    case $1 in
        --install-only) install_only=true ;;
        --verbose) ;; # This runner already streams vcpkg output.
        -h|--help)
            echo "Usage: $0 --install-only [--verbose]"
            exit 0
            ;;
        --*) echo "Unknown option: $1" >&2; exit 2 ;;
        *) echo "Unexpected positional argument: $1" >&2; exit 2 ;;
    esac
    shift
done

test "$install_only" = true || {
    echo "breakdown-test is an installation prerequisite. Pass --install-only" >&2
    exit 2
}
devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/../lorelei-ae/build/install}")
test -x "$vcpkg"
test -x "$devkit/bin/x86_64-linux-gnu-clang"

if test -e "$state" && test ! -f "$state/.lorelei-evaluations-workspace"; then
    echo "Refusing unmarked work directory: $state" >&2
    exit 2
fi
mkdir -p "$state"
touch "$state/.lorelei-evaluations-workspace"

export LORELEI_DEVKIT=$devkit
export VCPKG_MAX_CONCURRENCY=$(nproc)
install_lane()
{
    local lane=$1
    local triplet=$2
    "$vcpkg" install "breakdown-test:$triplet" \
        --overlay-ports="$overlay_dir/ports" \
        --overlay-triplets="$overlay_dir/triplets" \
        --x-install-root="$state/installed/$lane" \
        --x-buildtrees-root="$state/vcpkg/$lane/buildtrees" \
        --x-packages-root="$state/vcpkg/$lane/packages" \
        --downloads-root="$repo_root/vcpkg/downloads" \
        --triplet="$triplet"
}

install_lane hecate arm64-linux-ae
install_lane guest x64-linux-ae

prefix=$state/installed/hecate/arm64-linux-ae
test -f "$prefix/include/breakdown-test.h"
test -f "$prefix/lib/libbreakdown_test.so"
test -f "$state/installed/guest/x64-linux-ae/lib/libbreakdown_test.so"
echo "Installed breakdown-test at $prefix"
