vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO clibs/sha1
    REF ac99068faad00293dc41f0734a8c7f967aa6d7ce
    SHA512 704635befac7c5d09f0c078c46b720ed9f1c56d74b312e6d4a132b14877a540cc5534cfec0de397f5c93bb0524e1c13cbf7b2afd00ddd63d28647c7e6fd8044e
)

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib" "${CURRENT_PACKAGES_DIR}/include")
vcpkg_cmake_get_vars(vars)
include("${vars}")
vcpkg_execute_required_process(COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -O2 -fPIC -shared "${SOURCE_PATH}/sha1.c" "-I${SOURCE_PATH}" -Wl,-soname,libsha1.so -o "${CURRENT_PACKAGES_DIR}/lib/libsha1.so" WORKING_DIRECTORY "${SOURCE_PATH}" LOGNAME build)
set(TEST_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${TEST_DIR}")
vcpkg_execute_required_process(
    COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -O2 "${SOURCE_PATH}/test.c"
        "-I${SOURCE_PATH}" "-I${CURRENT_INSTALLED_DIR}/include"
        "-L${CURRENT_PACKAGES_DIR}/lib" -lsha1 "-L${CURRENT_INSTALLED_DIR}/lib" -lcunit
        -o "${TEST_DIR}/test"
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME build-upstream-tests
)
file(INSTALL "${SOURCE_PATH}/sha1.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/sha1.c")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
