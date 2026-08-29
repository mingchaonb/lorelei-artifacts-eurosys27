vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXrandr-${VERSION}.tar.xz"
    FILENAME "libXrandr-${VERSION}.tar.xz"
    SHA512 3cae1d2eb425dd3d3bd89f514a8e4bd9c696170ab6f3882f6db1936c30674b48277f2e485a8e3e47b3093fb1d9a32d2b054b064bd781db039e833b397aeeda9b
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xrandr)
set(XORG_LIBRARY_BASENAME libXrandr)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
