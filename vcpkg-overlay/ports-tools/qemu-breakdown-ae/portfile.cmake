# This evaluation tool is an optimized executable. A debug build would double
# build time and is not used by any public runner.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Fetch the dedicated breakdown branch of the Hecate-enabled QEMU fork. This
# revision contains the phase markers consumed by breakdown-test directly.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/qemu
    REF 759f9bd2cf8d8d8e7a36ff64599693cffaf2c354
    SHA512 1b916ec41eac35ec1300ff12b40f737ba50786d4e55423a702ca4fc80f39fabddcf6d9390eda7a13557ef6db19587b204d9ae75470d4e0370300728769c56e28
    HEAD_REF breakdown-timing
)

# Only x86-64 linux-user is needed. Documentation, system emulation, and
# unrelated utility programs are deliberately excluded from this tool port.
set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
file(MAKE_DIRECTORY "${BUILD_DIR}")
vcpkg_execute_required_process(
    COMMAND
        "${SOURCE_PATH}/configure"
        "--prefix=${CURRENT_PACKAGES_DIR}"
        --target-list=x86_64-linux-user
        --disable-docs
        --disable-system
        --disable-tools
        --disable-guest-agent
        --disable-werror
    WORKING_DIRECTORY "${BUILD_DIR}"
    LOGNAME "configure-${TARGET_TRIPLET}"
)

# Build and install the instrumented emulator under a namespaced tool path so
# no performance runner can select it accidentally.
vcpkg_find_acquire_program(NINJA)
vcpkg_execute_build_process(
    COMMAND "${NINJA}" -j${VCPKG_CONCURRENCY} qemu-x86_64
    WORKING_DIRECTORY "${BUILD_DIR}"
    LOGNAME "build-${TARGET_TRIPLET}"
)
file(INSTALL "${BUILD_DIR}/qemu-x86_64"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    USE_SOURCE_PERMISSIONS
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
