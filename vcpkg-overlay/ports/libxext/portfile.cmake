vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXext-${VERSION}.tar.xz"
    FILENAME "libXext-${VERSION}.tar.xz"
    SHA512 09cd230da472e87e4fdbc9b0f83a9181cc44af04c06fa4a7d8aa405e0f8551d3ac3a4b379249c44d97e1025b60d1c52f8ca13817eed0206e2bf3d66a55d89701
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xext)
set(XORG_LIBRARY_BASENAME libXext)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
