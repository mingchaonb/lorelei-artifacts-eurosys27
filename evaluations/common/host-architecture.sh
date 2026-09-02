#!/usr/bin/env bash

# Map the kernel architecture to the vcpkg triplets used by the AE.  Keep this
# in one place so game installation and execution select the same host ABI.
case $(uname -m) in
    aarch64 | arm64)
        AE_HOST_ARCH=arm64
        AE_HOST_MULTIARCH=aarch64-linux-gnu
        ;;
    riscv64)
        AE_HOST_ARCH=riscv64
        AE_HOST_MULTIARCH=riscv64-linux-gnu
        # vcpkg does not publish its helper-tool bundle for RV64. Use the
        # Ubuntu 24.04 CMake, Ninja and archive tools installed in the image.
        export VCPKG_FORCE_SYSTEM_BINARIES=1
        ;;
    *)
        echo "Unsupported AE host architecture: $(uname -m)" >&2
        return 1 2>/dev/null || exit 1
        ;;
esac

AE_HOST_TRIPLET=${AE_HOST_TRIPLET:-${AE_HOST_ARCH}-linux-ae}
AE_TOOL_TRIPLET=${AE_TOOL_TRIPLET:-${AE_HOST_ARCH}-linux}
export AE_HOST_ARCH AE_HOST_MULTIARCH AE_HOST_TRIPLET AE_TOOL_TRIPLET
