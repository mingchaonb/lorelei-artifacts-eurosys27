#!/usr/bin/env bash
set -euo pipefail

evaluations_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$evaluations_dir/.." && pwd)
source "$evaluations_dir/common/install-progress.sh"
source "$evaluations_dir/common/proxy-environment.sh"
source "$evaluations_dir/common/host-architecture.sh"
normalize_proxy_environment

# The detached metrics uploader can inherit an install-root lock after one
# vcpkg invocation and race the immediately following invocation. AE recipes
# do not need telemetry, so keep every package operation synchronous.
export VCPKG_DISABLE_METRICS=1

usage() {
    cat <<'EOF'
Usage: ./evaluations/install-games.sh [--plain]

Install the native host and guest x86-64 packages for every redistributable
game. Existing packages, downloads, and build state are reused. Failures do not
prevent later games from being attempted.

vcpkg output is always streamed above the progress display.
Recognized transient network failures are retried automatically.

  --plain  Disable the sticky terminal progress display.

Environment:
  INSTALL_NETWORK_ATTEMPTS  Maximum attempts after network failures, default: 5
EOF
}

plain=false
while (($#)); do
    case $1 in
        --plain) plain=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

export LORELEI_DEVKIT=${LORELEI_DEVKIT:-$repo_root/.work/devkit}
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

games=(assaultcube openarena redeclipse supertux supertuxkart)

# Classic-mode vcpkg does not replace an installed package merely because its
# overlay port-version changed. Each game has an isolated installation tree,
# so upgrade that tree first and then install either missing architecture.
install_game_packages() {
    local game=$1 work_dir=$2
    local common_args=(
        --overlay-ports="$overlay/ports"
        --overlay-triplets="$overlay/triplets"
        --downloads-root="$repo_root/vcpkg/downloads"
        --x-install-root="$work_dir/installed"
        --x-buildtrees-root="$work_dir/buildtrees"
        --x-packages-root="$work_dir/packages"
    )
    "$vcpkg" upgrade --no-dry-run "${common_args[@]}"
    "$vcpkg" install "$game:$AE_HOST_TRIPLET" "$game:x64-linux-ae" "${common_args[@]}"
}

install_progress_init Games "${#games[@]}" "$plain"
install_progress_setup
index=0
for game in "${games[@]}"; do
    ((index += 1))
    work_dir=$repo_root/.work/evaluations/games/$game
    install_progress_run "$game" "$index" install_game_packages "$game" "$work_dir" || true
done
install_progress_finish

if ((install_progress_failed)); then
    echo "One or more game packages failed to install." >&2
    exit 1
fi
