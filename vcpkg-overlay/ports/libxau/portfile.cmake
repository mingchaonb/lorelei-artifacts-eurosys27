# Use the official release archive because it contains a generated configure
# script. The registry port checks out Git and requires autoconf-archive from
# the evaluator's package manager, which would make the AE setup non-portable.
vcpkg_download_distfile(
    ARCHIVE
    URLS "https://xorg.freedesktop.org/archive/individual/lib/libXau-${VERSION}.tar.xz"
    FILENAME "libXau-${VERSION}.tar.xz"
    SHA512 4bbe8796f4a14340499d5f75046955905531ea2948944dfc3d6069f8b86c1710042bfc7918d459320557883e6631359d48e6173c69c62ff572314e864ff97c5e
)

# Extract a fresh source tree for this package build.
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# Configure through vcpkg-make so the same port works for native AArch64 and
# the x86-64 guest toolchain without executing target binaries.
vcpkg_make_configure(SOURCE_PATH "${SOURCE_PATH}")

# Install the shared library, public headers, and pkg-config metadata into the
# selected isolated vcpkg prefix.
vcpkg_make_install()
vcpkg_fixup_pkgconfig()

# Headers and metadata are architecture independent and need only one copy.
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

# Preserve the exact upstream license in the binary package.
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
