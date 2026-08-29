# Use the release archive with its generated configure script. This avoids the
# registry port's evaluator-host dependency on autoconf-archive.
vcpkg_download_distfile(
    ARCHIVE
    URLS "https://xorg.freedesktop.org/archive/individual/lib/libXdmcp-${VERSION}.tar.xz"
    FILENAME "libXdmcp-${VERSION}.tar.xz"
    SHA512 d7a1d70a58b7d34ddd01a91d3ccbc086a36626b7081cfcbb150d24288c6adad612b042ba7ea63a218595afb2ee04384c0f8ba84ee3c6bd29913724b54e898d83
)

# Extract, configure, and install through vcpkg-make for both AE triplets.
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
vcpkg_make_configure(SOURCE_PATH "${SOURCE_PATH}")
vcpkg_make_install()

# Relocate pkg-config paths to the isolated package prefix.
vcpkg_fixup_pkgconfig()

# Public headers and package metadata are shared by release and debug layouts.
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

# Preserve the exact upstream license in the binary package.
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
