# This port produces an evaluation tool, so only one optimized executable is built.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Fetch the exact reviewed AE commit. HEAD_REF documents the development branch
# while REF and SHA512 keep the normal installation source immutable.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/qemu
    REF 712379f27e692fd912b6773e32a996091b4dc413
    SHA512 3719a8e897d80519df4f81463bdc5e113a429d197a96f1d3bbd1738efbe09fb5e503145b6b5bb729aa533a22e7b39920f1c0804bcee0ca85f8ae361ad93419d5
    HEAD_REF ae
)

# QEMU uses its configure wrapper around Meson. Only x86-64 linux-user is
# required by this artifact, so system emulation, documentation, and unrelated
# command-line utilities are disabled.
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
        --disable-capstone
        --disable-werror
    WORKING_DIRECTORY "${BUILD_DIR}"
    LOGNAME "configure-${TARGET_TRIPLET}"
)

# Build only the emulator consumed by the evaluation scripts.
vcpkg_find_acquire_program(NINJA)
vcpkg_execute_build_process(
    COMMAND "${NINJA}" -j${VCPKG_CONCURRENCY} qemu-x86_64
    WORKING_DIRECTORY "${BUILD_DIR}"
    LOGNAME "build-${TARGET_TRIPLET}"
)

# Tool ports use a namespaced directory so they do not add implicit commands to
# the evaluator's PATH or collide with distribution-provided emulators.
file(INSTALL "${BUILD_DIR}/qemu-x86_64"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    USE_SOURCE_PERMISSIONS
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
