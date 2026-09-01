# This port produces an evaluation tool, so only one optimized executable is built.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Fetch the exact reviewed AE commit from the fork's ae branch.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/box64
    REF 28ef6be929e42669ac682b31a1dd9dfb31ce2ced
    SHA512 251db348347e30104965239d0696941e01acdb2e6b186440c503d3ba2d211cd1752a9f4b0afc149930164b7f0328592c8392b6f9496b4957e976555ffda5dfa5
    HEAD_REF ae
)

# Build the generic AArch64 dynarec configuration used by the AE. NOGIT avoids
# consulting an unavailable .git directory after vcpkg extracts its source
# archive. System-wide binfmt and compatibility-library installation are not
# part of this tool package.
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DARM_DYNAREC=ON
        -DNOGIT=ON
        -DNO_CONF_INSTALL=ON
        -DNO_LIB_INSTALL=ON
)
vcpkg_cmake_build(TARGET box64)

# Install only the emulator used by the benchmark lanes.
file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/box64"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    USE_SOURCE_PERMISSIONS
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
