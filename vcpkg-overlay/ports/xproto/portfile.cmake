vcpkg_download_distfile(
    ARCHIVE
    URLS "https://xorg.freedesktop.org/archive/individual/proto/xorgproto-${VERSION}.tar.xz"
    FILENAME "xorgproto-${VERSION}.tar.xz"
    SHA512 af0a8c8094fc6a490a886a8c048175762b6334798f2e48b6f6e19a7bb39ddbef05fa1237c4e9d9f1d870d24f5ca7a7c463044c41ceebd108f8ab0816677a582d
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}"
    PATCHES patches/allow-cross-clang-linker-probes.patch)

vcpkg_configure_meson(SOURCE_PATH "${SOURCE_PATH}" OPTIONS -Dlegacy=true)
vcpkg_install_meson()
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib")
if(EXISTS "${CURRENT_PACKAGES_DIR}/share/pkgconfig")
    file(RENAME "${CURRENT_PACKAGES_DIR}/share/pkgconfig" "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
endif()
vcpkg_fixup_pkgconfig(SKIP_CHECK)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
file(GLOB_RECURSE LICENSE_FILES "${SOURCE_PATH}/COPYING*")
vcpkg_install_copyright(FILE_LIST ${LICENSE_FILES})
