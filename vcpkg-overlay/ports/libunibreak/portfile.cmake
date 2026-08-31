vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO adah1972/libunibreak
    REF 3ce4bfa3129ff3738046a44a6db533d2ce25af2b
    SHA512 c1abc74335e4b5c9af24428aaba4826cc1ed27e8a9a3d0e9738feb95ea3d81d67946aa8e6ddd0ac9c7690643b170483eb803311c52670caf5a90f62ed9b0ac98
    HEAD_REF master
)
set(CONFIGURE_TRIPLET)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(CONFIGURE_TRIPLET BUILD_TRIPLET "--host=x86_64-linux-gnu")
endif()
vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}" AUTOCONFIG
    ${CONFIGURE_TRIPLET}
    OPTIONS --disable-static)
vcpkg_build_make(SUBPATH src BUILD_TARGET tests)
vcpkg_install_make()
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/share/doc")
set(test_install "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${test_install}/bin")
file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/src/.libs/tests"
    DESTINATION "${test_install}/bin"
    USE_SOURCE_PERMISSIONS)
file(INSTALL
    "${SOURCE_PATH}/src/LineBreakTest.txt"
    "${SOURCE_PATH}/src/WordBreakTest.txt"
    "${SOURCE_PATH}/src/GraphemeBreakTest.txt"
    DESTINATION "${test_install}/data")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENCE")
