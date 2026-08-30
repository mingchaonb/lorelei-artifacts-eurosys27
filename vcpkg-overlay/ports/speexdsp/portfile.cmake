# Fetch the exact official SpeexDSP release used by this evaluation. The
# archive checksum makes the source input reproducible.
vcpkg_download_distfile(ARCHIVE
    URLS "https://downloads.xiph.org/releases/speex/speexdsp-1.2.1.tar.gz"
    FILENAME "speexdsp-1.2.1.tar.gz"
    SHA512 41b5f37b48db5cb8c5a0f6437a4a8266d2627a5b7c1088de8549fe0bf0bb3105b7df8024fe207eef194096e0726ea73e2b53e0a4293d8db8e133baa0f8a3bad3
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

# Upstream does not ship a CMake build. Install the repository-owned build
# description before configuring so vcpkg builds one shared production DSO
# and all five upstream noinst test programs from the release sources.
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

# Keep one portable scalar configuration in both architectures. This avoids
# making the native and Hecate lanes exercise different SIMD implementations.
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DSPEEXDSP_BUILD_TESTS=ON
        -DSPEEXDSP_USE_NEON=OFF
        -DSPEEXDSP_USE_SSE=OFF
)

# Install the DSO, public headers, pkg-config metadata, and test executables.
vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()

# Debug headers and test drivers duplicate the release payload and are not
# used by the evaluation.
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
    "${CURRENT_PACKAGES_DIR}/debug/tools"
)

# Preserve the upstream license beside the installed package metadata.
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
