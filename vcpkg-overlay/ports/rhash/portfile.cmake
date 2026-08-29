vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO rhash/RHash
    REF 6562de382954d9893442b89b0e8b5c513eea6a88
    SHA512 9a772dd048c8de88a851e5aa8ffa6b477567ac94455c2c435a06c80302ad1847803cd6baf3024472a7a6c5573e8ecf4b1118a41cd5535ed0acb9387b7a4c114c
)

vcpkg_cmake_get_vars(vars)
include("${vars}")
set(RHASH_TARGET_OPTIONS)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    list(APPEND RHASH_TARGET_OPTIONS
        --target=x86_64-linux
        "--extra-cflags=--sysroot=$ENV{LORELEI_DEVKIT}/x86_64/sysroot -O2"
        "--extra-ldflags=--sysroot=$ENV{LORELEI_DEVKIT}/x86_64/sysroot"
    )
endif()
vcpkg_execute_required_process(
    COMMAND "${SOURCE_PATH}/configure"
        "--cc=${VCPKG_DETECTED_CMAKE_C_COMPILER}"
        --prefix=${CURRENT_PACKAGES_DIR}
        --libdir=${CURRENT_PACKAGES_DIR}/lib
        --disable-openssl
        --disable-gettext
        --enable-lib-shared
        --disable-lib-static
        ${RHASH_TARGET_OPTIONS}
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME configure
)
vcpkg_execute_required_process(
    COMMAND make -j${VCPKG_CONCURRENCY} install-lib-shared install-lib-headers
    WORKING_DIRECTORY "${SOURCE_PATH}"
    LOGNAME install
)
vcpkg_execute_required_process(
    COMMAND make -j${VCPKG_CONCURRENCY} test_shared
    WORKING_DIRECTORY "${SOURCE_PATH}/librhash"
    LOGNAME build-upstream-tests
)
file(INSTALL "${SOURCE_PATH}/librhash/test_shared"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests" TYPE PROGRAM)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
