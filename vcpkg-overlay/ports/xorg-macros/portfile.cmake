# The official release already contains configure. Using it avoids requiring
# autoconf-archive from the evaluator's OS package manager.
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

vcpkg_download_distfile(
    ARCHIVE
    URLS "https://xorg.freedesktop.org/archive/individual/util/util-macros-${VERSION}.tar.xz"
    FILENAME "util-macros-${VERSION}.tar.xz"
    SHA512 7d5ae8dbb6c1977e40c024f63d1405e7d5a40a38b90b01208d8dc1f1548e309734d1dec177b68bbf342a4d7d56ab0cfb4c8c36575c6a774b5a76a88d926c6d7b
)

# Configure and install the architecture-independent macro collection.
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
vcpkg_make_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_make_install()

# Put aclocal modules and package metadata where the downstream X.Org ports and
# vcpkg's pkg-config integration expect to find them.
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/xorg/aclocal")
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/share/xorg/util-macros")
file(COPY "${CURRENT_PACKAGES_DIR}/share/${PORT}/aclocal/" DESTINATION "${CURRENT_PACKAGES_DIR}/share/xorg/aclocal")
file(COPY "${CURRENT_PACKAGES_DIR}/share/${PORT}/util-macros/" DESTINATION "${CURRENT_PACKAGES_DIR}/share/xorg/util-macros")
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
file(COPY "${CURRENT_PACKAGES_DIR}/share/${PORT}/pkgconfig/xorg-macros.pc" DESTINATION "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
vcpkg_replace_string(
    "${CURRENT_PACKAGES_DIR}/lib/pkgconfig/xorg-macros.pc"
    "datarootdir=\${prefix}/share"
    "datarootdir=\${prefix}/share/xorg"
)
vcpkg_fixup_pkgconfig()

# Remove duplicate staging layouts and retain only release data.
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/share/${PORT}/aclocal" "${CURRENT_PACKAGES_DIR}/share/${PORT}/util-macros" "${CURRENT_PACKAGES_DIR}/share/${PORT}/pkgconfig")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
