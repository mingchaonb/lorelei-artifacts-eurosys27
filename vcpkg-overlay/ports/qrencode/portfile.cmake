vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO fukuchi/libqrencode
    REF "v${VERSION}"
    SHA512 584106e7bcaaa1ef2efe63d653daad38d4ff436eb4b185a1db3c747169c1ffa74149c3b1329bb0b8ae007903db0a7034aabf135cc196d91a37b5c61348154a65
    HEAD_REF master
    PATCHES
        patches/use-installed-test-data.patch
        patches/build-tests-without-optimization.patch
        patches/free-test-buffers-in-library.patch
        patches/read-test-errno-from-library.patch
)
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DWITH_TESTS=ON
    -DWITH_TOOLS=OFF
    -DWITHOUT_PNG=ON
    -DCMAKE_DISABLE_FIND_PACKAGE_PNG=ON
)
vcpkg_cmake_install()
set(test_build "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/tests")
set(test_names test_bitstream test_estimatebit test_split test_qrinput test_qrspec
    test_mqrspec test_qrencode test_split_urls test_monkey test_mask test_mmask test_rs)
set(test_install "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${test_install}/bin")
foreach(test_name IN LISTS test_names)
    file(INSTALL "${test_build}/${test_name}"
        DESTINATION "${test_install}/bin"
        USE_SOURCE_PERMISSIONS)
endforeach()
file(INSTALL "${test_build}/libcommon.so" "${test_build}/librscode.so"
    DESTINATION "${test_install}/lib"
    USE_SOURCE_PERMISSIONS)
file(GLOB test_headers "${SOURCE_PATH}/*.h")
file(INSTALL ${test_headers}
    DESTINATION "${test_install}/include")
file(INSTALL "${SOURCE_PATH}/tests/frame"
    DESTINATION "${test_install}")
vcpkg_cmake_config_fixup()
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/share/man")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
