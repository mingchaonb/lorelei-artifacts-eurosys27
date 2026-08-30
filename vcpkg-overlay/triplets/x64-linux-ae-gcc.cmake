if(NOT DEFINED ENV{LORELEI_DEVKIT})
    message(FATAL_ERROR "LORELEI_DEVKIT must name the installed Lorelei devkit")
endif()

set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Linux)
set(VCPKG_BUILD_TYPE release)

# zlib 1.3.2 built by the devkit Clang enters a data-dependent non-terminating
# path in Blink's AArch64 JIT. GNU's x86-64 cross compiler produces a working
# guest DSO and matches the GCC compiler family used by the native lane.
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/x64-linux-ae-gcc-toolchain.cmake")
set(VCPKG_ENV_PASSTHROUGH LORELEI_DEVKIT)
