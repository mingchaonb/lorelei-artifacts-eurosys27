vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO JuliaStrings/utf8proc
    REF "v${VERSION}"
    SHA512 148701fce506d076f03497b6d085f1993eff743debad4a2f6d3cbac91e19a5c22d9938245bdb460c1b22b51842c7416c42124db7416c684ee63d622490baac0e
    HEAD_REF master
    PATCHES patches/install-pinned-test-data.patch
)
vcpkg_download_distfile(NORMALIZATION_TEST
    URLS https://www.unicode.org/Public/17.0.0/ucd/NormalizationTest.txt
    FILENAME unicode-17.0.0-NormalizationTest.txt
    SHA512 aa62fef9d78f0fd12e0b98fbc174874e90acf60fda9e91ed542fbb610b2e8257efa20ed43728f3faf3dff0950434b85f539dfaceb161bde5875208ae7a66f758
)
vcpkg_download_distfile(GRAPHEME_BREAK_TEST
    URLS https://www.unicode.org/Public/17.0.0/ucd/auxiliary/GraphemeBreakTest.txt
    FILENAME unicode-17.0.0-GraphemeBreakTest.txt
    SHA512 28275f1b5c0b74bdf1486a6c68fea6f62e98b88092612e94d36d5aa439de67f57e87b6841d3b1a7dc49dede272d79a22ef4ddb163a51557c0c2e45bb1fc9b4e2
)
file(MAKE_DIRECTORY "${SOURCE_PATH}/test-data")
file(COPY_FILE "${NORMALIZATION_TEST}" "${SOURCE_PATH}/test-data/NormalizationTest.txt")
file(COPY_FILE "${GRAPHEME_BREAK_TEST}" "${SOURCE_PATH}/test-data/GraphemeBreakTest.txt")
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DUTF8PROC_ENABLE_TESTING=ON
)
vcpkg_cmake_install()
set(test_build "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
set(test_names case custom iterate misc printproperty valid maxdecomposition charwidth graphemetest normtest)
set(test_install "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${test_install}/bin")
foreach(test_name IN LISTS test_names)
    file(INSTALL "${test_build}/${test_name}"
        DESTINATION "${test_install}/bin"
        USE_SOURCE_PERMISSIONS)
endforeach()
file(INSTALL "${NORMALIZATION_TEST}"
    DESTINATION "${test_install}/data"
    RENAME NormalizationTest.txt)
file(INSTALL "${GRAPHEME_BREAK_TEST}"
    DESTINATION "${test_install}/data"
    RENAME GraphemeBreakTest.txt)
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/utf8proc)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.md")
