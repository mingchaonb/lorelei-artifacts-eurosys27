# This port produces a measurement-only Box64 executable, so build only the
# optimized configuration used by the callback breakdown.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Fetch the exact public commit from the dedicated breakdown branch. Keeping
# this separate from box64-ae prevents instrumentation from affecting the
# ordinary emulator used by performance comparisons.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/box64
    REF f02cdce1e00f2910dbaa9ea48daa5aecf78b6c8a
    SHA512 1102920f8d5b0452f6ec7c818b89e1530e3f74aa69b5abe948f7994795b927b64841c20217237e07908a62520d934ce78ea9014e1638556b8e486cafddfaf77e
    HEAD_REF breakdown-test-wrapper
)

# Build the AArch64 dynarec with the dedicated breakdown-test wrapper and the
# GetNativeOrAlt timing probes supplied by the branch. NOGIT keeps the build
# independent of a source checkout after vcpkg extracts the archive.
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DARM_DYNAREC=ON
        -DNOGIT=ON
        -DNO_CONF_INSTALL=ON
        -DNO_LIB_INSTALL=ON
)
vcpkg_cmake_build(TARGET box64)

# Install the instrumented executable under an unambiguous name. It is used
# only by the callback breakdown and must not replace the ordinary box64-ae
# executable used by performance comparisons.
file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/box64"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    USE_SOURCE_PERMISSIONS
)
file(RENAME
    "${CURRENT_PACKAGES_DIR}/tools/${PORT}/box64"
    "${CURRENT_PACKAGES_DIR}/tools/${PORT}/box64-callback-track"
)

# Preserve the upstream license in the vcpkg package metadata.
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
