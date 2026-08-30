# This port produces evaluation tools, so only one optimized configuration is built.
set(VCPKG_BUILD_TYPE release)
set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# Fetch the exact reviewed AE commit from the fork's ae branch.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO mingchaonb/FEX
    REF 1f19604271dbacd63984919074fd777c716a8f14
    SHA512 c7092bb5e5ff43db676f1be9846daad69c2037f044281ea172eb8781be95ba78e85c5f97655a780fd858c7ad23f060eccf49dc97eca65708807ed755d7f715e1
    HEAD_REF ae
)

# Git archives do not contain submodule bodies. Populate only the bundled
# dependencies required by the runtime-only configuration. Test binaries,
# Vulkan thunks, profiling support, and GUI configuration tools are disabled.
function(fex_populate_submodule destination repo ref sha512)
    vcpkg_from_github(
        OUT_SOURCE_PATH SUBMODULE_SOURCE
        REPO "${repo}"
        REF "${ref}"
        SHA512 "${sha512}"
    )
    file(REMOVE_RECURSE "${SOURCE_PATH}/${destination}")
    file(MAKE_DIRECTORY "${SOURCE_PATH}/${destination}")
    file(COPY "${SUBMODULE_SOURCE}/" DESTINATION "${SOURCE_PATH}/${destination}")
endfunction()

fex_populate_submodule(
    External/fmt
    fmtlib/fmt
    e424e3f2e607da02742f73db84873b8084fc714c
    8f52c9a3362a311662688f3af8e62cb86dd9af12cd92546dd43280f480f7a95a36b17abf79b8079d3ba7077d9e527a19d688df66a9ec11842501ffc8f62a4d4d
)
fex_populate_submodule(
    External/range-v3
    ericniebler/range-v3
    ca1388fb9da8e69314dda222dc7b139ca84e092f
    6a151236845d9758555be81640dba773abf90c2ee6410d3eadbdc7d993bbedcd359251c334a3fa20eb6148aa3d357e036ae5d94337a6837fd4ae09c3b842da9d
)
fex_populate_submodule(
    Source/Common/cpp-optparse
    Sonicadvance1/cpp-optparse
    9f94388a339fcbb0bc95c17768eb786c85988f6e
    600559354c8a3e233f7d2d855a8325b747b6656eb05fe13b3fae31f7f41154968b995bc3a519b0c61e5db904d4bca4cb17eb72a2f35a1a273e275ec34593b92f
)
fex_populate_submodule(
    External/jemalloc
    FEX-Emu/jemalloc
    ce24593018ca5d5af7e5661ceda9744e02b59f8f
    6152af0cc312c1583daaea06f99347d57a43628a6243854885bd9e769f98c5e75b537882aa9e79d49e5a4a16dcbf85513c939d5dd6425fb6492ea08bc04f1342
)
fex_populate_submodule(
    External/jemalloc_glibc
    FEX-Emu/jemalloc
    8436195ad5e1bc347d9b39743af3d29abee59f06
    093ad013d6de08c8c4822ff0b8256ed022f7139561dabd2295beb79f86e45536e8b673a869cb9d81905e734708fa4be17d04bbfaaaeb3d25e8d6c1c204fc5d9b
)
fex_populate_submodule(
    External/robin-map
    FEX-Emu/robin-map
    d5683d9f1891e5b04e3e3b2192b5349dc8d814ea
    23fe18c7d2dda9bc4216201a7e5935c8dc9f51066173e95d514360e3310c994c4dc7786a33f43cb7d15dcceb913375a48b8c02529eacde58c0a80f0e91e9b94d
)
fex_populate_submodule(
    External/drm-headers
    FEX-Emu/drm-headers
    0675d2f2910b46ba7e0fb9d6dff86f8d82b05660
    2b362a835e283ec74137d031cd8aa6150ef8fe06baf64899b98a3c315aca2f2c8806729fdc00e80059db95995f74106d8c71c8957707cdc95935ca5cf63b89ab
)

# FEX requires Clang. The AE runtime configuration disables FEX's own thunk,
# test, and configuration-UI builds while preserving its allocator setup and
# the Hecate-specific emulator changes.
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    GENERATOR Ninja
    OPTIONS
        -DCMAKE_C_COMPILER=clang
        -DCMAKE_CXX_COMPILER=clang++
        -DCMAKE_CXX_SCAN_FOR_MODULES=OFF
        -DCMAKE_DISABLE_FIND_PACKAGE_fmt=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_range-v3=ON
        -DBUILD_FEXCONFIG=OFF
        -DBUILD_TESTING=OFF
        -DBUILD_THUNKS=OFF
        -DENABLE_LTO=ON
        -DENABLE_GDB_SYMBOLS=ON
        -DENABLE_JEMALLOC=ON
        -DENABLE_JEMALLOC_GLIBC_ALLOC=ON
)
vcpkg_cmake_build(TARGET FEX)
vcpkg_cmake_build(TARGET FEXServer)

# Keep both the launcher and its helper together in a namespaced tool directory.
file(INSTALL
    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/Bin/FEX"
    "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/Bin/FEXServer"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}"
    USE_SOURCE_PERMISSIONS
)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
