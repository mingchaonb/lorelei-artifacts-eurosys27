vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO facebook/zstd
    REF "v${VERSION}"
    SHA512 26e441267305f6e58080460f96ab98645219a90d290a533410b1b0b1d2f870721c95f8384e342ee647c5e968385a5b7e30c2d04340c37f59b3e6d86762c3260c
    HEAD_REF dev
    PATCHES
        no-static-suffix.patch
        fix-emscripten-and-clang-cl.patch
        fix-windows-rc-compile.patch
        patches/allow-skipping-dictionary-training.patch
)

vcpkg_replace_string("${SOURCE_PATH}/build/cmake/CMakeLists.txt"
    "if (NOT ZSTD_BUILD_STATIC)"
    "if (NOT ZSTD_BUILD_STATIC AND NOT ZSTD_BUILD_SHARED)")
vcpkg_replace_string("${SOURCE_PATH}/build/cmake/tests/CMakeLists.txt"
    "libzstd_static"
    "libzstd_shared")
vcpkg_replace_string("${SOURCE_PATH}/build/cmake/programs/CMakeLists.txt"
    "if (ZSTD_MULTITHREAD_SUPPORT)\n    set_property(TARGET zstd APPEND PROPERTY COMPILE_DEFINITIONS \"ZSTD_MULTITHREAD\")"
    "if (FALSE)\n    set_property(TARGET zstd APPEND PROPERTY COMPILE_DEFINITIONS \"ZSTD_MULTITHREAD\")")

string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "static" ZSTD_BUILD_STATIC)
string(COMPARE EQUAL "${VCPKG_LIBRARY_LINKAGE}" "dynamic" ZSTD_BUILD_SHARED)

set(ZSTD_BUILD_PROGRAMS 1)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/build/cmake"
    OPTIONS
        -DZSTD_BUILD_SHARED=${ZSTD_BUILD_SHARED}
        -DZSTD_BUILD_STATIC=${ZSTD_BUILD_STATIC}
        -DZSTD_LEGACY_SUPPORT=1
        -DZSTD_BUILD_TESTS=1
        -DZSTD_PROGRAMS_LINK_SHARED=ON
        -DZSTD_BUILD_CONTRIB=0
        -DZSTD_MULTITHREAD_SUPPORT=1
    OPTIONS_RELEASE
        -DZSTD_BUILD_PROGRAMS=${ZSTD_BUILD_PROGRAMS}
    OPTIONS_DEBUG
        -DZSTD_BUILD_PROGRAMS=OFF
)

vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/zstd)
vcpkg_fixup_pkgconfig()

file(READ "${CURRENT_PACKAGES_DIR}/share/zstd/zstdTargets.cmake" targets)
if(targets MATCHES "-pthread")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/lib/pkgconfig/libzstd.pc" " -lzstd" " -lzstd -pthread")
    if(NOT VCPKG_BUILD_TYPE)
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig/libzstd.pc" " -lzstd" " -lzstd -pthread")
    endif()
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

if(VCPKG_TARGET_IS_WINDOWS AND VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    foreach(HEADER IN ITEMS zdict.h zstd.h zstd_errors.h)
        vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/${HEADER}" "defined(ZSTD_DLL_IMPORT) && (ZSTD_DLL_IMPORT==1)" "1" )
    endforeach()
endif()

if(VCPKG_TARGET_IS_WINDOWS AND ZSTD_BUILD_PROGRAMS)
    vcpkg_copy_tools(TOOL_NAMES zstd AUTO_CLEAN)
endif()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
set(ZSTD_UPSTREAM_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${ZSTD_UPSTREAM_DIR}/bin")
file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/programs/zstd" DESTINATION "${ZSTD_UPSTREAM_DIR}/bin" USE_SOURCE_PERMISSIONS)
file(INSTALL
    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/tests/datagen"
    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/tests/fullbench"
    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/tests/fuzzer"
    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/tests/zstreamtest"
    DESTINATION "${ZSTD_UPSTREAM_DIR}/bin" USE_SOURCE_PERMISSIONS)
file(COPY "${SOURCE_PATH}/tests/" DESTINATION "${ZSTD_UPSTREAM_DIR}/tests")
file(COPY "${SOURCE_PATH}/programs/" DESTINATION "${ZSTD_UPSTREAM_DIR}/programs")
file(COPY "${SOURCE_PATH}/lib/" DESTINATION "${ZSTD_UPSTREAM_DIR}/lib")
vcpkg_replace_string("${ZSTD_UPSTREAM_DIR}/lib/common/xxhash.h"
    "# define XXH_NOESCAPE __attribute__((noescape))"
    "# define XXH_NOESCAPE")
vcpkg_install_copyright(
    COMMENT "ZSTD is dual licensed under BSD and GPLv2."
    FILE_LIST
       "${SOURCE_PATH}/LICENSE"
       "${SOURCE_PATH}/COPYING"
)
