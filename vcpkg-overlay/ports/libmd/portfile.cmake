vcpkg_download_distfile(ARCHIVE
    URLS "https://gitlab.freedesktop.org/libbsd/libmd/-/archive/90c4f432134c608c7e2b4dd0a1d7ca5c40b92c7a/libmd-90c4f432134c608c7e2b4dd0a1d7ca5c40b92c7a.tar.gz"
    FILENAME "libmd-1.2.0.tar"
    SHA512 f287ac86e5d33eec204d1a773272745b96344c50fb1ddac6dce5700fda1128448afbebe24fac01ad974aa14b4abe411e13ff383bd541e9183b55e8960c34ae79
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}" AUTOCONFIG OPTIONS --disable-static)
vcpkg_install_make()
set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
vcpkg_execute_required_process(COMMAND make -j${VCPKG_CONCURRENCY} check TESTS=
    WORKING_DIRECTORY "${BUILD_DIR}" LOGNAME build-upstream-tests)
set(TEST_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${TEST_DIR}")
foreach(TEST_NAME md2 md4 md5 rmd160 sha1 sha2 sha3)
    file(INSTALL "${BUILD_DIR}/test/.libs/${TEST_NAME}" DESTINATION "${TEST_DIR}" TYPE PROGRAM)
endforeach()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
