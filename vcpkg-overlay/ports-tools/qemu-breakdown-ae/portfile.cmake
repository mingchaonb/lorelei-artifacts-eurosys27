# This evaluation tool is an optimized executable. A debug build would double
# build time and is not used by any public runner.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Start from the same reviewed Hecate-enabled QEMU revision as qemu-ae. The
# versioned patch adds only the phase markers consumed by breakdown-test.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/qemu
    REF 712379f27e692fd912b6773e32a996091b4dc413
    SHA512 3719a8e897d80519df4f81463bdc5e113a429d197a96f1d3bbd1738efbe09fb5e503145b6b5bb729aa533a22e7b39920f1c0804bcee0ca85f8ae361ad93419d5
    HEAD_REF ae
    PATCHES patches/lorelei-breakdown-timing.patch
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
