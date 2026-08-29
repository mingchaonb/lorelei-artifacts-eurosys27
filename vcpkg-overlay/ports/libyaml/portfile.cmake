vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO yaml/libyaml
    REF "${VERSION}"
    SHA512 a0f01e3fc616b65b18a4aa17692ee8ea1a84dc6387d1cf02ac7ef7ab7f46b9744c2aac0a047ff69d6c2da1d2a2d7b355c877da0db57e34d95cd4f37213ab6e7e
    HEAD_REF master
    PATCHES
        patches/build-tests-without-optimization.patch
)
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=ON)
vcpkg_cmake_install()
set(test_build "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
set(test_install "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${test_install}/bin")
foreach(test_name IN ITEMS test-version test-reader)
    file(INSTALL "${test_build}/${test_name}"
        DESTINATION "${test_install}/bin"
        USE_SOURCE_PERMISSIONS)
endforeach()
vcpkg_cmake_config_fixup(CONFIG_PATH cmake)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/License")
