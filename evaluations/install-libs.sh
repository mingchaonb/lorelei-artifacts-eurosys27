#!/usr/bin/env bash
set -euo pipefail

# Install every 1-libs recipe without running its native or Hecate tests.
evaluations_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$evaluations_dir/.." && pwd)
libs_dir=$evaluations_dir/1-libs
source "$evaluations_dir/common/install-progress.sh"

plain=false
while (($#)); do
    case $1 in
        --plain) plain=true ;;
        -h|--help)
            cat <<'EOF'
Usage: ./evaluations/install-libs.sh [--plain]

Call every library run.sh with --install-only. Existing vcpkg packages and the
shared download cache are reused. Failures do not prevent later libraries from
being attempted.

vcpkg output is always streamed above the progress display.

  --plain  Disable the sticky terminal progress display.
EOF
            exit 0
            ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

devkit=$(realpath -m "${LORELEI_DEVKIT:-$repo_root/.work/devkit}")
[[ -d $devkit ]] || { echo "Devkit not found: $devkit" >&2; exit 2; }
[[ -x $repo_root/vcpkg/vcpkg ]] || {
    echo "Missing repository-local vcpkg: $repo_root/vcpkg/vcpkg" >&2
    exit 2
}

mapfile -t libraries < <(
    while IFS= read -r runner; do
        name=$(basename "$(dirname "$runner")")
        printf '%s\n' "$name"
    done < <(find "$libs_dir" -mindepth 2 -maxdepth 2 -type f -name run.sh | sort)
)
((${#libraries[@]} > 0)) || { echo "No library recipes found" >&2; exit 1; }

install_progress_init Libraries "${#libraries[@]}" "$plain"
install_progress_setup
index=0
for name in "${libraries[@]}"; do
    ((index += 1))
    command=(env "LORELEI_DEVKIT=$devkit" "$libs_dir/$name/run.sh" --install-only --verbose)
    install_progress_run "$name" "$index" "${command[@]}" || true
done
install_progress_finish

if ((install_progress_failed)); then
    echo "Re-run this command after correcting the failed library recipes." >&2
    exit 1
fi
