# Fetch the official upstream release used by every evaluation lane.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libsdl-org/SDL_image
    REF "release-2.8.12"
    SHA512 738ae5c39a02753a11ce41b3739de42bb99b399d34698c3fde16a76745d4d3b05cd0b3d78d4b37b2859f5449b4ebbf04ad75d77910e47fff772f1070910eb84e
    HEAD_REF main
)

# The default feature builds upstream unchanged. The hlr feature supplies the
# devkit header, rewrites the image DSO closure, and rebuilds the same target.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

# Keep formats that SDL2_image implements internally. JPEG and PNG use the
# bundled stb backend so game recipes do not acquire extra DSO dependencies.
set(IMAGE_OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DSDL2IMAGE_INSTALL=ON
    -DSDL2IMAGE_TESTS=OFF
    -DSDL2IMAGE_SAMPLES=OFF
    -DSDL2IMAGE_BACKEND_IMAGEIO=OFF
    -DSDL2IMAGE_BACKEND_STB=ON
    -DSDL2IMAGE_DEPS_SHARED=OFF
    -DSDL2IMAGE_VENDORED=OFF
    -DSDL2IMAGE_AVIF=OFF
    -DSDL2IMAGE_JPG=ON
    -DSDL2IMAGE_JXL=OFF
    -DSDL2IMAGE_PNG=ON
    -DSDL2IMAGE_TIF=OFF
    -DSDL2IMAGE_WEBP=OFF
    -DSDL2IMAGE_PNM=ON
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND IMAGE_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once to produce the unmodified image DSO and exact production database.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${IMAGE_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(IMAGE_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(IMAGE_LIBRARY "${IMAGE_BUILD}/libSDL2_image-2.0.so.0.800.12")
    if(NOT EXISTS "${IMAGE_LIBRARY}")
        message(FATAL_ERROR "SDL2_image input not found: ${IMAGE_LIBRARY}")
    endif()

    # Restrict HLR to the 20 C translation units for the shared image target.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "CMakeFiles/SDL2_image.dir/"
            --build "${IMAGE_BUILD}"
            --library "${IMAGE_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name SDL2_image
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/include"
            --include "${CURRENT_INSTALLED_DIR}/include/SDL2"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # Internal format detector functions live in a C static initializer table.
    # The reviewed patch keeps those host-only pointers raw while retaining CCG.
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

    # Rebuild the shared image library against the lane's SDL2 dependency.
    vcpkg_cmake_build()
endif()

# Install the DSO, headers, package metadata, and upstream license.
vcpkg_cmake_install()
file(COPY "${SOURCE_PATH}/test/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests/data")
vcpkg_cmake_config_fixup(PACKAGE_NAME SDL2_image CONFIG_PATH lib/cmake/SDL2_image)
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
