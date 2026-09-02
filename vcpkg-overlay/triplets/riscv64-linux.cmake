set(VCPKG_TARGET_ARCHITECTURE riscv64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)
set(VCPKG_BUILD_TYPE release)

# vcpkg-make's default path options are not emitted with the system CMake
# available on Ubuntu 24.04 RV64.  Supply the normal vcpkg layout at triplet
# level so every autotools-based port stages files under the install root.
set(VCPKG_MAKE_CONFIGURE_OPTIONS
    "--disable-static"
    "--enable-shared"
    # DESTDIR supplies the package staging root.  A stable configure prefix
    # keeps package ABIs reusable across the per-recipe vcpkg install roots.
    "--prefix=/"
    "--bindir=\\\${prefix}/tools/${PORT}/bin"
    "--sbindir=\\\${prefix}/tools/${PORT}/sbin"
    "--libdir=\\\${prefix}/lib"
    "--includedir=\\\${prefix}/include"
    "--datarootdir=\\\${prefix}/share/${PORT}"
)
