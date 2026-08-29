# xtrans ships source headers consumed while building Xlib. Use the official
# release archive so no evaluator-host autoreconf packages are required.
vcpkg_download_distfile(
    ARCHIVE
    URLS "https://xorg.freedesktop.org/archive/individual/lib/xtrans-${VERSION}.tar.xz"
    FILENAME "xtrans-${VERSION}.tar.xz"
    SHA512 e0ac4a2df0eeacdf23cedd74fee063a8eea81d05c4c4c9a9a113b9b4238db7cacb3c831973ac647fe1a5b06426dcdf0b2f8be5ac27862700333269880e25725b
)

# Configure and install the architecture-independent source-header package.
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
vcpkg_make_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_make_install()

# xtrans headers are shared build inputs rather than normal public headers.
# Match the layout expected by its pkg-config metadata and vcpkg consumers.
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/${PORT}")
file(RENAME "${CURRENT_PACKAGES_DIR}/include" "${CURRENT_PACKAGES_DIR}/share/${PORT}/include")
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib")
file(RENAME "${CURRENT_PACKAGES_DIR}/share/${PORT}/pkgconfig" "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
vcpkg_fixup_pkgconfig()
vcpkg_replace_string(
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/xtrans.pc"
    "includedir=\${prefix}/include"
    "includedir=\${prefix}/share/${PORT}/include"
)

# Keep only the single release-layout copy and install upstream licensing.
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
