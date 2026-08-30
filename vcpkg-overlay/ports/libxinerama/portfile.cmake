vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXinerama-${VERSION}.tar.xz"
    FILENAME "libXinerama-${VERSION}.tar.xz"
    SHA512 64bff837941625120da43b8876db4204bc5740bcf3147997fc4df1475f90d6d9e3f9caa8748c7ebbf69d681be8e5ab4bc40f82c56c367dddcec3ab27d1c71573
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xinerama)
set(XORG_LIBRARY_BASENAME libXinerama)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
