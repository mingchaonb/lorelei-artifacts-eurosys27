# Fetch the exact upstream SDL release through vcpkg. The checksum makes source
# acquisition reproducible. The first patch makes upstream tests link the shared
# SDL target so the guest loader can replace SDL with the generated thunk.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libsdl-org/SDL
    REF "release-${VERSION}"
    SHA512 d3cf7d356b79184dd211c9fbbfcb2a83d1acb68ee549ab82be109cd899039f18f0dbf3aedbf0800793c3a68580688014863b5d9bf79bcd366ff0e88252955e3c
    HEAD_REF main
    PATCHES patches/dynamic-tests.patch
)

# Resolve the artifact root from this overlay port. HLR needs the shared guest
# libc-shim header because the SDL manifests describe FILE and stream ownership.
get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(COMMON_INCLUDE_DIR "${REPO_ROOT}/evaluations/common/include")

# Convert vcpkg features into independent build options. The tests feature builds
# upstream executables. The hlr feature rewrites only production sources below
# SDL/src, so callers may combine both features without rewriting test programs.
set(BUILD_TESTS OFF)
set(RUN_HLR OFF)
if("tests" IN_LIST FEATURES)
    set(BUILD_TESTS ON)
endif()
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()
# Build a shared SDL library because Lorelei replaces its dynamic dependency at
# runtime. Only dummy audio and video backends are enabled for the claimed AE
# scope. Real devices, display servers, and nondeterministic system services are
# intentionally excluded.
set(SDL_OPTIONS
    -DSDL_SHARED=ON
    -DSDL_STATIC=OFF
    -DSDL_TEST=${BUILD_TESTS}
    -DSDL_TESTS=${BUILD_TESTS}
    -DSDL_INSTALL_TESTS=${BUILD_TESTS}
    -DSDL_ALSA=OFF
    -DSDL_ARTS=OFF
    -DSDL_DISKAUDIO=OFF
    -DSDL_ESD=OFF
    -DSDL_JACK=OFF
    -DSDL_NAS=OFF
    -DSDL_OSS=OFF
    -DSDL_PIPEWIRE=OFF
    -DSDL_PULSEAUDIO=OFF
    -DSDL_SNDIO=OFF
    -DSDL_DUMMYAUDIO=ON
    -DSDL_X11=OFF
    -DSDL_WAYLAND=OFF
    -DSDL_KMSDRM=OFF
    -DSDL_RPI=OFF
    -DSDL_VIVANTE=OFF
    -DSDL_OFFSCREEN=OFF
    -DSDL_DUMMYVIDEO=ON
    -DSDL_INSTALL_CMAKEDIR=share/sdl2
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    -DCMAKE_DISABLE_FIND_PACKAGE_Git=ON
)

# The x86-64 package contains guest test programs only. Disable optional host
# integrations that are unavailable in the cross sysroot and irrelevant to the
# dummy-backend validation scope.
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    list(APPEND SDL_OPTIONS
        -DSDL_DBUS=OFF
        -DSDL_HIDAPI=OFF
        -DSDL_HIDAPI_JOYSTICK=OFF
        -DSDL_IBUS=OFF
        -DSDL_LIBUDEV=OFF
        -DSDL_LIBSAMPLERATE=OFF
        -DSDL_OPENGL=OFF
        -DSDL_OPENGLES=OFF
        -DSDL_VULKAN=OFF
    )
endif()

# HLR-generated sources include Lorelei runtime declarations. Add the devkit
# headers to both the initial compilation database and the rewritten rebuild.
if(RUN_HLR)
    list(APPEND SDL_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Configure and build once before any rewriting. For the native and guest test
# packages this is the final build. For HLR this build supplies the exact shared
# object and compile_commands.json consumed by the analysis pass.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${SDL_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    # Locate the unmodified host library produced above. The versioned filename
    # is pinned by the SDL release, which avoids accidentally selecting a symlink.
    set(SDL_INPUT_LIBRARY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/libSDL2-2.0.so.0.2800.5")
    if(NOT EXISTS "${SDL_INPUT_LIBRARY}")
        message(FATAL_ERROR "SDL input library not found: ${SDL_INPUT_LIBRARY}")
    endif()

    # Generate TLC statistics with callback replacement disabled, then run HLR
    # over exactly the translation units in the CMake compilation database.
    # run-hlr.py preserves HLRStat.json and the rewritten source list for audit.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${CMAKE_CURRENT_LIST_DIR}/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --build "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
            --library "${SDL_INPUT_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --common-include "${COMMON_INCLUDE_DIR}"
            --output "${HLR_AUDIT_DIR}"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # Automatic rewriting intentionally stops before the few reviewed SDL
    # adaptations. Check the patch first so an upstream or HLR output change
    # fails loudly instead of creating a partially patched package.
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

    # Reuse the configured build tree. CMake sees the rewritten source files and
    # recompiles the affected objects into the final HLR host library.
    vcpkg_cmake_build()
endif()

# Install the selected library and, for the tests feature, upstream test binaries
# and resources. Normalize CMake and pkg-config metadata to vcpkg conventions.
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH share/sdl2)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/share/licenses"
    "${CURRENT_PACKAGES_DIR}/share/installed-tests"
)

# Ship the HLR audit products with the HLR package. They let an evaluator inspect
# the analyzed source closure without keeping the disposable vcpkg build tree.
if(RUN_HLR)
    file(INSTALL "${HLR_AUDIT_DIR}/HLRStat.json" "${HLR_AUDIT_DIR}/hlr-sources.txt"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit")
endif()

# Record the upstream SDL license in the standard vcpkg package location.
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
