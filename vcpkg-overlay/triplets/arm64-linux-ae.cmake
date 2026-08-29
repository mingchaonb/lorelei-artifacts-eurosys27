set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)
set(VCPKG_BUILD_TYPE release)

# Build X.Org support libraries inside vcpkg instead of accepting the empty
# Linux system-package placeholders. This keeps native and guest inputs
# symmetric and supplies guest headers such as X11/Xauth.h.
set(X_VCPKG_FORCE_VCPKG_X_LIBRARIES ON)
