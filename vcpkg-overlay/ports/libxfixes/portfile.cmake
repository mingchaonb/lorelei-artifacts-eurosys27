vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXfixes-${VERSION}.tar.xz"
    FILENAME "libXfixes-${VERSION}.tar.xz"
    SHA512 87542927ba9839fdd83282b0fba1bd2afae853ffe4e0f5f548915de22432bbc34a064578ba8527ba6041a993ee27390ba6ee2f1a957cb961717d45026e40ec75
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xfixes)
set(XORG_LIBRARY_BASENAME libXfixes)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
