vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO Cyan4973/xxHash
    REF "v${VERSION}"
    SHA512 8b5c8b9aad4e869f28310b12cc314037feda81d92f26c23eaecdb35dc65042ca2e65f2e9606033e62a31bcc737a9a950500ffcbdb8677d6ab20e820ea14f2b79
    HEAD_REF dev
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES xxhsum XXHASH_BUILD_XXHSUM
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}/cmake_unofficial"
    OPTIONS ${FEATURE_OPTIONS}
)

vcpkg_cmake_install()
file(INSTALL "${SOURCE_PATH}/xxhash.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/upstream-source")
file(INSTALL
    "${SOURCE_PATH}/tests/sanity_test.c"
    "${SOURCE_PATH}/tests/sanity_test_vectors.h"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/upstream-source/tests")
file(INSTALL
    "${SOURCE_PATH}/cli/xsum_arch.h"
    "${SOURCE_PATH}/cli/xsum_config.h"
    "${SOURCE_PATH}/cli/xsum_os_specific.h"
    "${SOURCE_PATH}/cli/xsum_os_specific.c"
    "${SOURCE_PATH}/cli/xsum_output.h"
    "${SOURCE_PATH}/cli/xsum_output.c"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/upstream-source/cli")
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/xxHash)

if("xxhsum" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES xxhsum AUTO_CLEAN)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

vcpkg_fixup_pkgconfig()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
