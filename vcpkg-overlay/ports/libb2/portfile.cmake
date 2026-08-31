vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO BLAKE2/libb2
    REF 2c5142f12a2cd52f3ee0a43e50a3a76f75badf85
    SHA512 cf29cf9391ae37a978eb6618de6f856f3defa622b8f56c2d5a519ab34fd5e4d91f3bb868601a44e9c9164a2992e80dde188ccc4d1605dffbdf93687336226f8d
)

set(CONFIGURE_TRIPLET)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    # The Lorelei compiler is Clang-based, so vcpkg cannot infer the GNU host
    # tuple from its executable name. Tell Autoconf explicitly that the output
    # runs on x86-64 instead of probing it on the AArch64 build machine.
    set(CONFIGURE_TRIPLET BUILD_TRIPLET "--host=x86_64-linux-gnu")
endif()

vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    AUTOCONFIG
    ${CONFIGURE_TRIPLET}
    OPTIONS
        --disable-static
        --disable-native
        --disable-openmp
)
vcpkg_install_make()
set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
vcpkg_execute_required_process(COMMAND make -j${VCPKG_CONCURRENCY} check TESTS=
    WORKING_DIRECTORY "${BUILD_DIR}" LOGNAME build-upstream-tests)
file(GLOB TEST_BINS "${BUILD_DIR}/src/.libs/*-test")
file(INSTALL ${TEST_BINS} DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests" TYPE PROGRAM)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
