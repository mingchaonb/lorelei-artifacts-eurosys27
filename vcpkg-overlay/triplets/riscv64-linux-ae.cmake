set(VCPKG_TARGET_ARCHITECTURE riscv64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)
set(VCPKG_BUILD_TYPE release)

# Keep autotools ports in the regular vcpkg layout when RV64 uses Ubuntu's
# system CMake.  See the matching native triplet for details.
set(VCPKG_MAKE_CONFIGURE_OPTIONS
    "--disable-static"
    "--enable-shared"
    "--prefix=/"
    "--bindir=\\\${prefix}/tools/${PORT}/bin"
    "--sbindir=\\\${prefix}/tools/${PORT}/sbin"
    "--libdir=\\\${prefix}/lib"
    "--includedir=\\\${prefix}/include"
    "--datarootdir=\\\${prefix}/share/${PORT}"
)

# Build X.Org support libraries inside vcpkg so the RV64 Hecate packages have
# the same self-contained host and guest inputs as the AArch64 packages.
set(X_VCPKG_FORCE_VCPKG_X_LIBRARIES ON)
