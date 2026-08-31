vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO tlwg/libthai
    REF "v${VERSION}"
    SHA512 a33ef585c6f503eb6b609b73ddc5f3960ec58dc10fd07205eaa60596709ece47934571ca21b01a294c172f4a5fc374038a8726c1ed07aabf12b0bdd1a4565320
    HEAD_REF master
    PATCHES patches/link-tests-to-shared-library.patch
)
set(CONFIGURE_TRIPLET)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(CONFIGURE_TRIPLET BUILD_TRIPLET "--host=x86_64-linux-gnu")
endif()
vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}" AUTOCONFIG
    ${CONFIGURE_TRIPLET}
    OPTIONS
    --disable-static
    --disable-doxygen-doc
    "TRIETOOL=${CURRENT_HOST_INSTALLED_DIR}/tools/libdatrie/trietool"
)
vcpkg_build_make(BUILD_TARGET check OPTIONS "TESTS=")
vcpkg_install_make()
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/share/doc")
set(test_build "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/tests/.libs")
set(test_names test_thctype test_thcell test_thinp test_thrend test_thstr thsort
    test_thbrk test_thwchar test_thwbrk)
set(test_install "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${test_install}/bin")
foreach(test_name IN LISTS test_names)
    file(INSTALL "${test_build}/${test_name}"
        DESTINATION "${test_install}/bin"
        USE_SOURCE_PERMISSIONS)
endforeach()
file(INSTALL "${SOURCE_PATH}/tests/sorttest.txt" "${SOURCE_PATH}/tests/sorted.txt"
    DESTINATION "${test_install}/data")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
