#!/usr/bin/env bash
set -euo pipefail

evaluations_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$evaluations_dir/.." && pwd)

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    cat <<'EOF'
Usage: ./evaluations/install-games.sh

Install the native AArch64 and guest x86-64 packages for every redistributable
game. vcpkg output is streamed directly to the terminal.
EOF
    exit 0
fi
[[ $# == 0 ]] || { echo "Unexpected positional argument: $1" >&2; exit 2; }

export LORELEI_DEVKIT=${LORELEI_DEVKIT:-$repo_root/../lorelei-ae/build/install}
vcpkg=$repo_root/vcpkg/vcpkg
overlay=$repo_root/vcpkg-overlay

[[ -x $vcpkg ]] || {
    echo "Missing repository-local vcpkg executable: $vcpkg" >&2
    exit 2
}
[[ -d $LORELEI_DEVKIT ]] || {
    echo "Lorelei devkit not found: $LORELEI_DEVKIT" >&2
    exit 2
}

for game in assaultcube openarena redeclipse supertux supertuxkart; do
    work_dir=$repo_root/.work/evaluations/games/$game
    echo
    echo "Install game packages: $game"
    "$vcpkg" install "$game:arm64-linux-ae" "$game:x64-linux-ae" \
        --overlay-ports="$overlay/ports" \
        --overlay-triplets="$overlay/triplets" \
        --downloads-root="$repo_root/vcpkg/downloads" \
        --x-install-root="$work_dir/installed" \
        --x-buildtrees-root="$work_dir/buildtrees" \
        --x-packages-root="$work_dir/packages"
done
