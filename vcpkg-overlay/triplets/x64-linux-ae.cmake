if(NOT DEFINED ENV{LORELEI_DEVKIT})
    message(FATAL_ERROR "LORELEI_DEVKIT must name the installed Lorelei devkit")
endif()

set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)
set(VCPKG_BUILD_TYPE release)

# The released cross devkit does not ship clang-scan-deps.  Disable C++ module
# dependency scanning for ordinary library builds that do not use modules.
list(APPEND VCPKG_CMAKE_CONFIGURE_OPTIONS
    -DCMAKE_CXX_SCAN_FOR_MODULES=OFF
    -DALSOFT_ENABLE_MODULES=OFF
)

# Build X.Org support libraries inside vcpkg instead of accepting the empty
# Linux system-package placeholders. The guest cannot consume host headers,
# and the matching native package keeps the evaluation lanes comparable.
set(X_VCPKG_FORCE_VCPKG_X_LIBRARIES ON)

set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/x64-linux-ae-toolchain.cmake")
set(VCPKG_ENV_PASSTHROUGH LORELEI_DEVKIT)
