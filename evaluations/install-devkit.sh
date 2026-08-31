#!/usr/bin/env bash

set -euo pipefail

evaluations_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$evaluations_dir/.." && pwd)
source "$evaluations_dir/common/proxy-environment.sh"
normalize_proxy_environment
release_tag=eurosys27-ae-1
release_base=https://github.com/mingchaonb/lorelei/releases/download/$release_tag
install_dir=$repo_root/.work/devkit
cache_dir=$repo_root/.cache

case $(uname -m) in
    aarch64 | arm64)
        host_arch=aarch64
        archive_sha256=18246d10a5fcb305d6c921c22efb7c796df5d65e43cd176ff6ea715e94098807
        ;;
    riscv64)
        host_arch=riscv64
        archive_sha256=8c57341f755f29a533923f4838fa10dfe79f156f47703454e33c1f67833fb012
        ;;
    *)
        echo "Unsupported host architecture: $(uname -m)" >&2
        echo "The EuroSys 2027 AE release provides AArch64 and RISC-V 64 devkits." >&2
        exit 1
        ;;
esac

archive_name=lorelei-devkit-$host_arch-ae.tar.xz
archive_path=$cache_dir/$archive_name
archive_url=$release_base/$archive_name

validate_devkit() {
    local root=$1
    test -x "$root/bin/LoreTLC" \
        && test -x "$root/bin/LoreHLR" \
        && test -x "$root/bin/x86_64-linux-gnu-clang" \
        && test -f "$root/lib/libLoreHostRT.so" \
        && test -f "$root/x86_64/lib/libLoreGuestRT.so"
}

if validate_devkit "$install_dir"; then
    echo "Lorelei devkit is already installed at $install_dir"
    exit 0
fi

if test -e "$install_dir"; then
    echo "Refusing to replace an incomplete devkit at $install_dir" >&2
    echo "Remove that directory and run this script again." >&2
    exit 1
fi

mkdir -p "$cache_dir" "$repo_root/.work"

if ! echo "$archive_sha256  $archive_path" | sha256sum --check --status 2>/dev/null; then
    echo "Downloading $archive_name"
    curl --fail --location --retry 3 --output "$archive_path.part" "$archive_url"
    mv "$archive_path.part" "$archive_path"
fi

echo "$archive_sha256  $archive_path" | sha256sum --check

staging_dir=$(mktemp -d "$repo_root/.work/devkit-install.XXXXXX")
cleanup() {
    rm -rf "$staging_dir"
}
trap cleanup EXIT

echo "Extracting $archive_name"
tar -xJf "$archive_path" -C "$staging_dir"
extracted_dir=$staging_dir/lorelei-devkit-$host_arch

if ! validate_devkit "$extracted_dir"; then
    echo "The downloaded archive does not contain the expected devkit layout." >&2
    exit 1
fi

mv "$extracted_dir" "$install_dir"
echo "Lorelei devkit installed at $install_dir"
