vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO google/brotli
    REF v${VERSION} # v1.1.0
    SHA512 f94542afd2ecd96cc41fd21a805a3da314281ae558c10650f3e6d9ca732b8425bba8fde312823f0a564c7de3993bdaab5b43378edab65ebb798cefb6fd702256
    HEAD_REF master
    PATCHES
        install.patch
        pkgconfig.patch
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBROTLI_DISABLE_TESTS=ON
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()
vcpkg_cmake_config_fixup(CONFIG_PATH share/unofficial-brotli PACKAGE_NAME unofficial-brotli)

vcpkg_download_distfile(BROTLI_TESTDATA
    URLS "https://github.com/google/brotli/releases/download/v${VERSION}/testdata.txz"
    FILENAME "brotli-${VERSION}-testdata.txz"
    SHA512 d185cd3bdb3eff08ab0e8010ebd9dc53378b4a675e0d65d2c56072cfa182d39423424ac503bf95c115549faea88d553e1064c72d990281d4b5a169dab43a8fe6)
set(BROTLI_TESTDATA_DIR "${CURRENT_BUILDTREES_DIR}/testdata-${VERSION}")
file(REMOVE_RECURSE "${BROTLI_TESTDATA_DIR}")
file(ARCHIVE_EXTRACT INPUT "${BROTLI_TESTDATA}" DESTINATION "${BROTLI_TESTDATA_DIR}")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/tools")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/share/man")

# Under emscripten the brotli executable tool is produced with .js extension but vcpkg_copy_tools
# has no special behaviour in this case and searches for the tool name with no extension
if(VCPKG_TARGET_IS_EMSCRIPTEN)
	set(TOOL_SUFFIX ".js" )
endif()

vcpkg_copy_tools(TOOL_NAMES "brotli${TOOL_SUFFIX}" SEARCH_DIR "${CURRENT_PACKAGES_DIR}/tools/brotli")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
# Inputs used by every roundtrip test present in the official release archive.
# The larger Canterbury corpus is intentionally not downloaded implicitly by
# upstream CMake and is therefore recorded as unavailable release data.
file(INSTALL
    "${SOURCE_PATH}/c/enc/encode.c"
    "${SOURCE_PATH}/c/common/dictionary.h"
    "${SOURCE_PATH}/c/dec/decode.c"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/upstream-tests/roundtrip")
file(INSTALL
    "${BROTLI_TESTDATA_DIR}/tests/testdata/alice29.txt"
    "${BROTLI_TESTDATA_DIR}/tests/testdata/asyoulik.txt"
    "${BROTLI_TESTDATA_DIR}/tests/testdata/lcet10.txt"
    "${BROTLI_TESTDATA_DIR}/tests/testdata/plrabn12.txt"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/upstream-tests/roundtrip")
file(INSTALL
    "${SOURCE_PATH}/tests/testdata/empty"
    "${SOURCE_PATH}/tests/testdata/empty.compressed"
    "${SOURCE_PATH}/tests/testdata/ukkonooa"
    "${SOURCE_PATH}/tests/testdata/ukkonooa.compressed"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/upstream-tests/compatibility")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
