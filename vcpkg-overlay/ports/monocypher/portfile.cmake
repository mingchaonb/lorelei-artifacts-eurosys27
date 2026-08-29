vcpkg_download_distfile(ARCHIVE
    URLS "https://monocypher.org/download/monocypher-4.0.3.tar.gz"
    FILENAME "monocypher-4.0.3.tar.gz"
    SHA512 40904ada5c7ee4f7741733e38b69a30a4b0561cbffba5ffe7c2dce16136d540251ec0d9056ff606510d3b5b708fb8a40db7e0870d4a0b2dc17ba2bfb880f8965
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib" "${CURRENT_PACKAGES_DIR}/include")
vcpkg_cmake_get_vars(vars)
include("${vars}")
vcpkg_execute_required_process(COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -O2 -fPIC -shared "${SOURCE_PATH}/src/monocypher.c" "${SOURCE_PATH}/src/optional/monocypher-ed25519.c" "-I${SOURCE_PATH}/src" "-I${SOURCE_PATH}/src/optional" -Wl,-soname,libmonocypher.so.4 -o "${CURRENT_PACKAGES_DIR}/lib/libmonocypher.so.4" WORKING_DIRECTORY "${SOURCE_PATH}" LOGNAME build)
file(CREATE_LINK "libmonocypher.so.4" "${CURRENT_PACKAGES_DIR}/lib/libmonocypher.so" SYMBOLIC)
set(TEST_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${TEST_DIR}")
vcpkg_execute_required_process(
    COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -std=c99 -O2
        "${SOURCE_PATH}/tests/test.c" "${SOURCE_PATH}/tests/utils.c"
        "-I${SOURCE_PATH}/src" "-I${SOURCE_PATH}/src/optional" "-I${SOURCE_PATH}/tests"
        "-L${CURRENT_PACKAGES_DIR}/lib" -l:libmonocypher.so.4
        -o "${TEST_DIR}/test.out"
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME build-upstream-tests
)
file(INSTALL "${SOURCE_PATH}/src/monocypher.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(INSTALL "${SOURCE_PATH}/src/optional/monocypher-ed25519.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENCE.md")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
