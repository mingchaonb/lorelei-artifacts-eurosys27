# Fetch the exact official release used by this evaluation.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libtom/libtommath
    REF "v1.3.0"
    SHA512 3dbd7053a670afa563a069a9785f1aa4cab14a210bcd05d8fc7db25bd3dcce36b10a3f4f54ca92d75a694f891226f01bdf6ac15bacafeb93a8be6b04c579beb3
    HEAD_REF master
)

# The default feature builds the official source unchanged. The hlr feature
# adds the devkit header, rewrites the shared-library closure, and rebuilds it.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

# Build one shared DSO without demo programs. This leaves exactly the 154
# production translation units owned by the libtommath target.
set(TOMMATH_OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_TESTING=OFF
    -DENABLE_CCACHE=OFF
    -DCOMPILE_LTO=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND TOMMATH_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once before HLR so the tool consumes the exact DSO and compilation
# database corresponding to the selected release and options.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${TOMMATH_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(TOMMATH_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(TOMMATH_LIBRARY "${TOMMATH_BUILD}/libtommath.so.1.3.0")
    if(NOT EXISTS "${TOMMATH_LIBRARY}")
        message(FATAL_ERROR "libtommath input not found: ${TOMMATH_LIBRARY}")
    endif()

    # Filter out all non-production commands, generate TLC metadata without
    # callback replacement, run HLR, and retain the complete audit inputs.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "CMakeFiles/libtommath.dir/"
            --build "${TOMMATH_BUILD}"
            --library "${TOMMATH_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name tommath
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # The detected FDG belongs to LibTomMath's internal static random-source
    # initializer. Keep it raw while CCG handles the callback installed later
    # by mp_rand_source.
    vcpkg_find_acquire_program(GIT)
    vcpkg_execute_required_process(
        COMMAND "${GIT}" apply --check "${CMAKE_CURRENT_LIST_DIR}/patches/post-hlr.patch"
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME post-hlr-check
    )
    vcpkg_execute_required_process(
        COMMAND "${GIT}" apply "${CMAKE_CURRENT_LIST_DIR}/patches/post-hlr.patch"
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME post-hlr-apply
    )

    # Rebuild the same DSO from the rewritten source tree.
    vcpkg_cmake_build()
endif()

# Install headers, the DSO, package metadata, and the official license.
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/libtommath)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/bin")

# Export the exact HLR evidence through the package for the top-level runner.
if(RUN_HLR)
    file(INSTALL
        "${HLR_AUDIT_DIR}/HLR-Stat.json"
        "${HLR_AUDIT_DIR}/TLC-ThunkStat.json"
        "${HLR_AUDIT_DIR}/compile_commands.json"
        "${HLR_AUDIT_DIR}/hlr-sources.txt"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit"
    )
endif()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
