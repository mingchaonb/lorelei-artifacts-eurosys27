vcpkg_from_sourceforge(OUT_SOURCE_PATH SOURCE_PATH REPO mpg123/mpg123 REF 1.33.7 FILENAME mpg123-1.33.7.tar.bz2 SHA512 694743802bb7be0f4a39bf62e681ae0bfed769cb87dc6c5b6fb5f9245966631efb5c5b9bd58588f7af55ced5d020f97c8a54993e71b5295bc45ebd152473f40e PATCHES patches/hecate-test-runner.patch)
set(CONFIGURE_TRIPLET)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(CONFIGURE_TRIPLET BUILD_TRIPLET "--host=x86_64-linux-gnu")
endif()
vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}"
    ${CONFIGURE_TRIPLET}
    OPTIONS --disable-static --enable-shared --disable-components --enable-libmpg123 --enable-libsyn123 --with-cpu=generic --disable-network)
vcpkg_install_make()
vcpkg_build_make(
    BUILD_TARGET "src/tests/seek_whence;src/tests/seek_accuracy;src/tests/resample_total;src/tests/text;src/tests/textprint;src/tests/plain_id3"
    LOGFILE_ROOT build-tests
)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/tools")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/" DESTINATION "${CURRENT_PACKAGES_DIR}/tools/mpg123/upstream-tests/build" USE_SOURCE_PERMISSIONS)
file(INSTALL "${SOURCE_PATH}/" DESTINATION "${CURRENT_PACKAGES_DIR}/tools/mpg123/upstream-tests/source" USE_SOURCE_PERMISSIONS)
