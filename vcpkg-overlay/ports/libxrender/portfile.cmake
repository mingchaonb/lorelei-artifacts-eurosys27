vcpkg_download_distfile(
    ARCHIVE
    URLS "https://www.x.org/releases/individual/lib/libXrender-${VERSION}.tar.xz"
    FILENAME "libXrender-${VERSION}.tar.xz"
    SHA512 3d24a6877b500608e3e2a393532a99d4fd54fc343375d8fb51dfbb1b50cedf002c7722f771cf7776f93cb6e0421ca5966ce45435cb402d5f12a398f9ea743474
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
set(XORG_HLR_NAME Xrender)
set(XORG_LIBRARY_BASENAME libXrender)
include("${CMAKE_CURRENT_LIST_DIR}/../../tools/xorg-hlr-port.cmake")
