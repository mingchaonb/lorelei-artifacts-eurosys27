vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXcursor-${VERSION}.tar.xz"
    FILENAME "libXcursor-${VERSION}.tar.xz"
    SHA512 069a1eb27a0ee1b29b251bb6c2d0688543a791d6862fad643279e86736e1c12ca6fc02b85b8611c225a9735dc00efab84672d42b547baa97304362f0c5ae0b5a
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xcursor)
set(XORG_LIBRARY_BASENAME libXcursor)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
