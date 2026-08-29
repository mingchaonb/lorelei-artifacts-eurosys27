# Fetch the exact official Expat release used by the evaluation. The checksum
# prevents an upstream archive change from silently changing the source input.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libexpat/libexpat
    REF "R_2_8_2"
    SHA512 e60e6d6ae9d0115f41186f06f3854008054863f0b29a58d44142f5b30057a494337145d820b5e18270b8ca3e779e318a757fcc6bf64d6d204e5498df5eeb2195
    HEAD_REF master
)

# The upstream repository keeps the CMake project below expat/. Build only the
# shared production library and omit tools, examples, documentation, and tests.
set(EXPAT_SOURCE "${SOURCE_PATH}/expat")
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

set(EXPAT_OPTIONS
    -DEXPAT_BUILD_DOCS=OFF
    -DEXPAT_BUILD_EXAMPLES=OFF
    -DEXPAT_BUILD_TESTS=OFF
    -DEXPAT_BUILD_TOOLS=OFF
    -DEXPAT_BUILD_PKGCONFIG=ON
    -DEXPAT_SHARED_LIBS=ON
    -DEXPAT_SYMBOL_VERSIONING=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND EXPAT_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# The first build is final for native and guest packages. For the HLR feature it
# also produces the exact DSO and compilation database consumed by the rewriter.
vcpkg_cmake_configure(SOURCE_PATH "${EXPAT_SOURCE}" OPTIONS ${EXPAT_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    # Expat 2.8.2 encodes its ABI age in this versioned DSO filename. Fail if the
    # pinned release no longer produces the reviewed input.
    set(EXPAT_INPUT_LIBRARY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/libexpat.so.1.12.2")
    if(NOT EXISTS "${EXPAT_INPUT_LIBRARY}")
        message(FATAL_ERROR "Expat input library not found: ${EXPAT_INPUT_LIBRARY}")
    endif()

    # Generate TLC metadata with callback replacement disabled, retain the exact
    # seven-unit compilation database, and rewrite only Expat production sources.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${EXPAT_SOURCE}"
            --source-root "${EXPAT_SOURCE}/lib"
            --build "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
            --library "${EXPAT_INPUT_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name expat
            --output "${HLR_AUDIT_DIR}"
            --include "${EXPAT_SOURCE}/lib"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # HLR embeds LoreFileContext.c into the rewritten production translation
    # unit, so rebuilding the configured tree produces the final host DSO.
    vcpkg_cmake_build()
endif()

# Install the selected library and normalize CMake and pkg-config metadata to
# vcpkg conventions. Debug products are not part of this release-only recipe.
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH "lib/cmake/expat-2.8.2")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/share/doc")

# Preserve HLR inputs beside the installed host package for evaluator audit.
if(RUN_HLR)
    file(INSTALL
        "${HLR_AUDIT_DIR}/HLR-Stat.json"
        "${HLR_AUDIT_DIR}/TLC-ThunkStat.json"
        "${HLR_AUDIT_DIR}/compile_commands.json"
        "${HLR_AUDIT_DIR}/hlr-sources.txt"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit"
    )
endif()

vcpkg_install_copyright(FILE_LIST "${EXPAT_SOURCE}/COPYING")
