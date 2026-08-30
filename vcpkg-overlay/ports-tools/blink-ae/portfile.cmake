# This port produces an evaluation tool, so only one optimized executable is built.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Fetch the exact reviewed AE commit from the fork's ae branch.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/blink
    REF 63e08279f577b348b2cdfaf26fa2bfd0b2c50b4e
    SHA512 0366490a4f3898d8179d4e18cef0eae2791726c3484443e65f23966103999462146f0b78c343ddc9b6b1b68c159b3f512eceabdc22a1cddd9aff14f244fa60e8
    HEAD_REF ae
)

# Blink has a generated Make configuration rather than a CMake install target.
# Configure and build its release-mode emulator in the extracted source tree.
find_program(MAKE make REQUIRED)
vcpkg_execute_required_process(
    COMMAND "${SOURCE_PATH}/configure" MODE=rel
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME "configure-${TARGET_TRIPLET}"
)
vcpkg_execute_build_process(
    COMMAND "${MAKE}" -j${VCPKG_CONCURRENCY} MODE=rel o/rel/blink/blink
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME "build-${TARGET_TRIPLET}"
)

# Install only the emulator used by the benchmark lanes.
file(INSTALL "${SOURCE_PATH}/o/rel/blink/blink"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    USE_SOURCE_PERMISSIONS
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
