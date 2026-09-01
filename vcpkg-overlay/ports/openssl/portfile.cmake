vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO openssl/openssl
    REF a279090b9cd6b682a5a178410765a63e619fa2d9
    SHA512 c13b4d63c57a40ea98119447a1ffa8b6a920e95cb864a86aae8a69a698365cf4e9646dc4058fe2126899c92fbf63a4c44130255ced7b0ce7dc2db24d8b02bfe6
)

vcpkg_cmake_get_vars(vars)
include("${vars}")
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(OPENSSL_TARGET linux-aarch64)
    set(OPENSSL_CFLAGS "-O2")
    set(OPENSSL_LDFLAGS "")
else()
    set(OPENSSL_TARGET linux-x86_64)
    set(OPENSSL_CFLAGS "--sysroot=$ENV{LORELEI_DEVKIT}/x86_64/sysroot -O2")
    set(OPENSSL_LDFLAGS "--sysroot=$ENV{LORELEI_DEVKIT}/x86_64/sysroot")
endif()
vcpkg_execute_required_process(
    COMMAND "${CMAKE_COMMAND}" -E env
        "CC=${VCPKG_DETECTED_CMAKE_C_COMPILER}"
        "CFLAGS=${OPENSSL_CFLAGS}"
        "LDFLAGS=${OPENSSL_LDFLAGS}"
        "${SOURCE_PATH}/Configure" "${OPENSSL_TARGET}"
        shared no-asm --prefix=/ --libdir=lib --openssldir=/ssl
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME configure
)
vcpkg_execute_required_process(
    COMMAND make -j${VCPKG_CONCURRENCY} build_sw
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME build-software
)
vcpkg_execute_required_process(COMMAND make DESTDIR=${CURRENT_PACKAGES_DIR} install_sw WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}" LOGNAME install)

# Build the focused SHA-256 client used by the CLI evaluation.  The monolithic
# openssl app imports unrelated management APIs that are outside this workload.
set(AE_TEST_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${AE_TEST_DIR}")
separate_arguments(OPENSSL_COMPILE_FLAGS NATIVE_COMMAND "${OPENSSL_CFLAGS}")
vcpkg_execute_required_process(
    COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" ${OPENSSL_COMPILE_FLAGS}
        -O2 -Wno-deprecated-declarations
        "${CMAKE_CURRENT_LIST_DIR}/lorelei/sha256-ae.c"
        "-I${CURRENT_PACKAGES_DIR}/include" "-L${CURRENT_PACKAGES_DIR}/lib"
        -lcrypto -o "${AE_TEST_DIR}/sha256-ae"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME build-ae-sha256
)
file(GLOB OPENSSL_STATIC_ARCHIVES "${CURRENT_PACKAGES_DIR}/lib/*.a")
file(REMOVE ${OPENSSL_STATIC_ARCHIVES})
vcpkg_fixup_pkgconfig()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
