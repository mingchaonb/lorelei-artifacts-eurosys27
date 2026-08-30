# This port produces an evaluation tool, so only one optimized executable is built.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Fetch the exact reviewed AE commit from the fork's ae branch.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/box64
    REF 248d84398198d467ebd54dfdc4fb1c0bb127ee91
    SHA512 8a6f21bf5a2a591886532664572c009b6a55b513832416b4566b0f9daf62ad5b9e811983fe8f44a648ea0e4c3f4b3f0bc8c35943899545fb88de7929b80c05f0
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
