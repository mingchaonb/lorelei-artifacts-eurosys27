vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO amosnier/sha-2
    REF 565f65009bdd98267361b17d50cddd7c9beb3e6c
    SHA512 8bf16538a18669e989a51936a0e7756535529aa4eb2b6d85eab7f1b9bfd9c50d15d789974a83ca04a376b903e4a10513eec4b82d22a02c7088352f964529b1c5
)

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib" "${CURRENT_PACKAGES_DIR}/include")
vcpkg_cmake_get_vars(vars)
include("${vars}")
vcpkg_execute_required_process(COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -O2 -fPIC -shared "${SOURCE_PATH}/sha-256.c" "-I${SOURCE_PATH}" -Wl,-soname,libsha2.so -o "${CURRENT_PACKAGES_DIR}/lib/libsha2.so" WORKING_DIRECTORY "${SOURCE_PATH}" LOGNAME build)
set(TEST_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${TEST_DIR}")
vcpkg_execute_required_process(
    COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -O2 "${SOURCE_PATH}/test.c"
        "-I${SOURCE_PATH}" "-L${CURRENT_PACKAGES_DIR}/lib" -lsha2
        -o "${TEST_DIR}/test"
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME build-upstream-tests
)
file(INSTALL "${SOURCE_PATH}/sha-256.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.md")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
