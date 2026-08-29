vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libsdl-org/SDL_ttf
    REF "release-${VERSION}"
    SHA512 c07037ac4ccbc5fff5fa6ed58e749995d70d719ab220412141f279ea34a564a36a1cd10c6d82e6ad5c02b928e000b2937b69ca29515f689b83550e382b1bedaf
    HEAD_REF SDL2
    PATCHES patches/install-lorelei-test.patch
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/lorelei-test-text.c" DESTINATION "${SOURCE_PATH}")
vcpkg_download_distfile(DEJAVU_ARCHIVE
    URLS https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.tar.bz2
    FILENAME dejavu-fonts-ttf-2.37.tar.bz2
    SHA512 bafa39321021097432777f0825d700190c23f917d754a4504722cd8946716c22c083836294dab7f3ae7cf20af63c4d0944f3423bf4aa25dbca562d1f30e00654
)
vcpkg_extract_source_archive(DEJAVU_SOURCE_PATH ARCHIVE "${DEJAVU_ARCHIVE}")

# The hlr feature performs the same analysis as transformed libraries even
# though this API description is expected to produce no source rewrites.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

# Use system-style vcpkg FreeType, disable HarfBuzz, and build one shared DSO.
set(TTF_OPTIONS
    -DSDL2TTF_HARFBUZZ=OFF
    -DSDL2TTF_SAMPLES=OFF
    -DSDL2TTF_VENDORED=OFF
    -DBUILD_SHARED_LIBS=ON
    -DLORELEI_INSTALL_TEST=ON
)
list(APPEND TTF_OPTIONS -DCMAKE_EXPORT_COMPILE_COMMANDS=ON)
if(RUN_HLR)
    list(APPEND TTF_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once to obtain the exact SDL_ttf.c compilation command and host DSO.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${TTF_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(TTF_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(TTF_LIBRARY "${TTF_BUILD}/libSDL2_ttf-2.0.so.0.2400.0")
    if(NOT EXISTS "${TTF_LIBRARY}")
        message(FATAL_ERROR "SDL2_ttf input not found: ${TTF_LIBRARY}")
    endif()

    # Run HLR against only the shared target. The expected outcome is one
    # translation unit with zero CCG, zero FDG, and zero rewritten files.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "CMakeFiles/SDL2_ttf.dir/"
            --build "${TTF_BUILD}"
            --library "${TTF_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name SDL2_ttf
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}"
            --include "${CURRENT_INSTALLED_DIR}/include"
            --include "${CURRENT_INSTALLED_DIR}/include/SDL2"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )
endif()

# Install the unchanged DSO plus the zero-hit audit as reproducible evidence.
vcpkg_cmake_install()
file(INSTALL "${DEJAVU_SOURCE_PATH}/ttf/DejaVuSans.ttf"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests/data"
    RENAME DejaVuSans.ttf)
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/SDL2_ttf)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/share/licenses")
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
