vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jwerle/murmurhash.c
    REF 10ba9c25abbcf8952b5f4abecf9bf4fc148e8e65
    SHA512 71d84a2a57a5763e53442aeb04384c13a9a7056b1651161ff5da5d34857be360feb7d78f25428d37ba3818d276dae029e0e004dcbcb88ee200f3863fe1680b66
)

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib" "${CURRENT_PACKAGES_DIR}/include")
vcpkg_cmake_get_vars(vars)
include("${vars}")
vcpkg_execute_required_process(COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -O2 -fPIC -shared -DMURMURHASH_WANTS_HTOLE32=1 "${SOURCE_PATH}/murmurhash.c" "-I${SOURCE_PATH}" -Wl,-soname,libmurmurhash.so -o "${CURRENT_PACKAGES_DIR}/lib/libmurmurhash.so" WORKING_DIRECTORY "${SOURCE_PATH}" LOGNAME build)
set(TEST_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${TEST_DIR}")
vcpkg_execute_required_process(
    COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -O2 -DMURMURHASH_WANTS_HTOLE32=1
        "${SOURCE_PATH}/test.c" "-I${SOURCE_PATH}" "-L${CURRENT_PACKAGES_DIR}/lib"
        -lmurmurhash -o "${TEST_DIR}/test"
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME build-upstream-tests
)
file(INSTALL "${SOURCE_PATH}/murmurhash.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
