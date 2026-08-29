set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_SYSROOT "$ENV{LORELEI_DEVKIT}/x86_64/sysroot")
set(CMAKE_C_COMPILER "$ENV{LORELEI_DEVKIT}/bin/x86_64-linux-gnu-clang")
set(CMAKE_CXX_COMPILER "$ENV{LORELEI_DEVKIT}/bin/x86_64-linux-gnu-clang++")
set(CMAKE_FIND_ROOT_PATH "$ENV{LORELEI_DEVKIT}/x86_64/sysroot")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# Search the guest sysroot and explicit vcpkg prefix paths. ONLY incorrectly
# rewrites vcpkg's absolute dependency paths beneath the sysroot, which makes
# cross-built packages such as FreeType unable to find their installed PNG DSO.
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
