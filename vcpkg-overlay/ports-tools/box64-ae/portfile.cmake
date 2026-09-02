# This port produces an evaluation tool, so only one optimized executable is built.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Fetch the exact reviewed AE commit from the fork's ae branch.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/box64
    REF 28ef6be929e42669ac682b31a1dd9dfb31ce2ced
    SHA512 251db348347e30104965239d0696941e01acdb2e6b186440c503d3ba2d211cd1752a9f4b0afc149930164b7f0328592c8392b6f9496b4957e976555ffda5dfa5
    HEAD_REF ae
)

# Select the dynarec backend that matches the physical AE host. NOGIT avoids
# consulting an unavailable .git directory after vcpkg extracts its source
# archive. System-wide binfmt and compatibility-library installation are not
# part of this tool package.
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    set(BOX64_ARCH_OPTIONS -DARM_DYNAREC=ON)
elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "riscv64")
    set(BOX64_ARCH_OPTIONS -DRV64=ON -DRV64_DYNAREC=ON)
else()
    message(FATAL_ERROR "box64-ae supports only arm64 and riscv64 hosts")
endif()
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${BOX64_ARCH_OPTIONS}
        -DNOGIT=ON
        -DNO_CONF_INSTALL=ON
        -DNO_LIB_INSTALL=ON
)
vcpkg_cmake_build(TARGET box64)

# Install only the emulator used by the benchmark lanes.
file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/box64"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    USE_SOURCE_PERMISSIONS
)

# Preserve only the wrapper sources consumed by the coverage and effort
# exporter. Binary-cache restores do not retain vcpkg's extracted build tree,
# so the installed tool package must carry this auditable source subset.
set(COVERAGE_WRAPPERS
    wrappedzstd
    wrappedlibavformat58
    wrappedlibavcodec58
    wrappedlibavutil56
    wrappedsdl2
    wrappedvulkan
    wrappedlibgl
    wrappedlibz
    wrappedlibx11
    wrappedlibxcb
    wrappedbz2
    wrappedbrotlidec
    wrappedexpat
    wrappedcurl
    wrappedevent21
    wrappedidn2
    wrappedlzma
    wrappedlibogg
    wrappedlibopus
    wrappedlibsndfile
)
foreach(STEM IN LISTS COVERAGE_WRAPPERS)
    file(INSTALL
        "${SOURCE_PATH}/src/wrapped/${STEM}.c"
        "${SOURCE_PATH}/src/wrapped/${STEM}_private.h"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/coverage-source"
    )
endforeach()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
