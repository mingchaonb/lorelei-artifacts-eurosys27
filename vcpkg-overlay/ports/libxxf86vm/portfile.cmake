vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXxf86vm-${VERSION}.tar.xz"
    FILENAME "libXxf86vm-${VERSION}.tar.xz"
    SHA512 d1051c9698a884d86e5beb00d5ee148d2b5ded7fd05168861f722b89643ad9b7f7d220f0cbb64b290a69faf9a6630181533aaddb01c9c68b46f1e5625030f094
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xxf86vm)
set(XORG_LIBRARY_BASENAME libXxf86vm)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
