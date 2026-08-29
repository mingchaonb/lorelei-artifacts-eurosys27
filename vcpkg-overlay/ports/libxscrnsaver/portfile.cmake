vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXScrnSaver-${VERSION}.tar.xz"
    FILENAME "libXScrnSaver-${VERSION}.tar.xz"
    SHA512 1c0be0d15c5e7b50a3eb4a239e2c833c44b693b111c7f64c409f9abf8051356572acadebc8b295555683ff6bd4895acdbe32b15a538c971f15d8aa4e6b7fd51b
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xss)
set(XORG_LIBRARY_BASENAME libXss)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
