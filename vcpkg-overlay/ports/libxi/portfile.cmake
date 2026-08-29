vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXi-${VERSION}.tar.xz"
    FILENAME "libXi-${VERSION}.tar.xz"
    SHA512 6348aae8f595217e26f348184dd594d83af800949f649bfd11b6aef7387faa5624ed18551fe2c3a38c8deab9d7473f72fd7e3e8472cff3ff30d4bb3fb2e6dc31
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xi)
set(XORG_LIBRARY_BASENAME libXi)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
