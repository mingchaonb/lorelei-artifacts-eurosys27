# Fetch the official upstream tag used by both the native and Hecate lanes.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libuv/libuv
    REF "v1.52.1"
    SHA512 c23bb26f8fdcf678dbf14bcee9855830927a40b8ae64dfa287ef1e910f37ad30cb868ecdeaad6f7b2bf3f3fccca1a7282a31b22c547206b672f923d0651f5b0c
    HEAD_REF v1.x
)

# The default feature builds upstream unchanged. The hlr feature supplies the
# devkit header, rewrites the shared DSO closure, and rebuilds the same target.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

# Build only the production shared library. Tests, benchmarks, sanitizers, and
# QEMU-specific upstream modes are outside this directed evaluation.
set(UV_OPTIONS
    -DLIBUV_BUILD_TESTS=OFF
    -DLIBUV_BUILD_BENCH=OFF
    -DLIBUV_BUILD_SHARED=ON
    -DBUILD_TESTING=OFF
    -DQEMU=OFF
    -DASAN=OFF
    -DTSAN=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND UV_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once to produce the unmodified libuv DSO and exact production
# compilation database consumed by TLC and HLR.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${UV_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(UV_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(UV_LIBRARY "${UV_BUILD}/libuv.so.1.0.0")
    if(NOT EXISTS "${UV_LIBRARY}")
        message(FATAL_ERROR "libuv input not found: ${UV_LIBRARY}")
    endif()

    # Restrict HLR to the shared uv target. The same source files also appear in
    # the static target, so this filter prevents duplicate transformation units.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "CMakeFiles/uv.dir/"
            --build "${UV_BUILD}"
            --library "${UV_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name uv
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/include"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # HLR recognizes libuv's internal worker tables as FDG. These callbacks are
    # host-internal, so the reviewed patch retains their raw host addresses.
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

    # Rebuild the same shared target from the reviewed rewritten source tree.
    vcpkg_cmake_build()
endif()

# Install the DSO, public headers, CMake metadata, pkg-config metadata, and
# upstream license into the lane-specific prefix.
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/libuv)
vcpkg_fixup_pkgconfig()
vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/include/uv.h" "defined(USING_UV_SHARED)" "1")
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
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
