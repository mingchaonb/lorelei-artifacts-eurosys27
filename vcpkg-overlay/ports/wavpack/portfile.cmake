# Fetch the official upstream release used by every evaluation lane.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO dbry/WavPack
    REF "5.9.0"
    SHA512 51534cb55b6efe5ec04feb3019bdadba58662fdb9df27921c92e31931ddc9fdd053412b29bc25c510ddcee47cbf07d2b2cdb292337972f0a6b8fc3f04531bff4
)

# The default feature builds upstream unchanged. The hlr feature supplies the
# devkit header, rewrites the shared DSO closure, and rebuilds the same targets.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

# Build the production shared library and upstream wvtest. Command-line tools,
# plugins, legacy decoding, and external libiconv are not needed by this suite.
set(WAVPACK_OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_TESTING=ON
    -DWAVPACK_BUILD_PROGRAMS=OFF
    -DWAVPACK_BUILD_COOLEDIT_PLUGIN=OFF
    -DWAVPACK_BUILD_WINAMP_PLUGIN=OFF
    -DWAVPACK_INSTALL_DOCS=OFF
    -DWAVPACK_ENABLE_THREADS=ON
    -DWAVPACK_ENABLE_LEGACY=OFF
    -DWAVPACK_ENABLE_LIBICONV=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND WAVPACK_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once to produce the unmodified DSO, wvtest, and exact compilation
# database consumed by TLC and HLR.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${WAVPACK_OPTIONS})
vcpkg_cmake_build()

set(WAVPACK_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
if(RUN_HLR)
    set(WAVPACK_LIBRARY "${WAVPACK_BUILD}/libwavpack.so.1.2.8")
    if(NOT EXISTS "${WAVPACK_LIBRARY}")
        message(FATAL_ERROR "WavPack input not found: ${WAVPACK_LIBRARY}")
    endif()

    # Keep only the 23 production commands for the shared wavpack target. The
    # two wvtest commands exercise the DSO but must not themselves be rewritten.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "CMakeFiles/wavpack.dir/"
            --build "${WAVPACK_BUILD}"
            --library "${WAVPACK_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name wavpack
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/include"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # Register the block-output callback ABI as metadata, export the HLR file
    # context, and retain host-internal static callbacks at raw host addresses.
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

    # Rebuild both the rewritten shared library and its upstream exerciser.
    vcpkg_cmake_build()
endif()

# Install the public library package and preserve wvtest as an AE-only tool.
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/WavPack)
vcpkg_copy_pdbs()
vcpkg_fixup_pkgconfig()
file(INSTALL "${WAVPACK_BUILD}/wvtest"
    DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/ae-tools"
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin")
if(VCPKG_TARGET_TRIPLET MATCHES "-ae$")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
endif()

# Copy HLR audit material out of the ephemeral build tree through the package.
if(RUN_HLR)
    file(INSTALL
        "${HLR_AUDIT_DIR}/HLR-Stat.json"
        "${HLR_AUDIT_DIR}/TLC-ThunkStat.json"
        "${HLR_AUDIT_DIR}/compile_commands.json"
        "${HLR_AUDIT_DIR}/hlr-sources.txt"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit"
    )
endif()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/license.txt")
