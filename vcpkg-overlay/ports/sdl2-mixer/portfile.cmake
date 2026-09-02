# Fetch the official upstream release used by every evaluation lane.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libsdl-org/SDL_mixer
    REF "release-2.8.2"
    SHA512 4c2ba587a89721e060472b65e8a846ed3012121b4de7a2952704dab5df5f9e5d828a4105a7eb9b2fd65158ea9264e8b53eb689b87cb7f098452c2ab959a25a06
    HEAD_REF main
)

# The default feature builds upstream unchanged. The hlr feature supplies the
# devkit header, rewrites the mixer DSO closure, and rebuilds the same target.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

# Keep the built-in WAVE path used by the workload and disable optional music
# codecs, command players, samples, and dynamically loaded dependencies.
set(MIXER_OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DSDL2MIXER_INSTALL=ON
    -DSDL2MIXER_SAMPLES=OFF
    -DSDL2MIXER_DEPS_SHARED=OFF
    -DSDL2MIXER_VENDORED=OFF
    -DSDL2MIXER_CMD=OFF
    -DSDL2MIXER_FLAC=OFF
    -DSDL2MIXER_GME=OFF
    -DSDL2MIXER_MOD=OFF
    -DSDL2MIXER_MP3=OFF
    -DSDL2MIXER_MIDI=OFF
    -DSDL2MIXER_OPUS=OFF
    -DSDL2MIXER_VORBIS=OFF
    -DSDL2MIXER_WAVE=ON
    -DSDL2MIXER_WAVPACK=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND MIXER_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once to produce the unmodified mixer DSO and exact production database.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${MIXER_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(MIXER_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(MIXER_LIBRARY "${MIXER_BUILD}/libSDL2_mixer-2.0.so.0.800.2")
    if(NOT EXISTS "${MIXER_LIBRARY}")
        message(FATAL_ERROR "SDL2_mixer input not found: ${MIXER_LIBRARY}")
    endif()

    # Restrict HLR to the production C translation units for the shared target.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}/src"
            --output-contains "CMakeFiles/SDL2_mixer.dir/"
            --build "${MIXER_BUILD}"
            --library "${MIXER_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name SDL2_mixer
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/include"
            --include "${CURRENT_INSTALLED_DIR}/include/SDL2"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # HLR cannot emit a runtime FDG call in a static-storage initializer.
    # Keep the upstream host function address there.  The generated CCG at
    # the call site handles it directly, while runtime callback assignments
    # still use the FDG transformations produced by HLR.
    find_program(PATCH_EXECUTABLE patch REQUIRED)
    vcpkg_execute_required_process(
        COMMAND "${PATCH_EXECUTABLE}" --dry-run --forward -p1
            --input "${CMAKE_CURRENT_LIST_DIR}/patches/post-hlr.patch"
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME post-hlr-check
    )
    vcpkg_execute_required_process(
        COMMAND "${PATCH_EXECUTABLE}" --forward -p1
            --input "${CMAKE_CURRENT_LIST_DIR}/patches/post-hlr.patch"
        WORKING_DIRECTORY "${SOURCE_PATH}"
        LOGNAME post-hlr-apply
    )

    # Rebuild the shared mixer library from the HLR-rewritten sources.
    vcpkg_cmake_build()
endif()

# Install the DSO, headers, package metadata, and upstream license.
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME SDL2_mixer CONFIG_PATH lib/cmake/SDL2_mixer)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")

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
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
