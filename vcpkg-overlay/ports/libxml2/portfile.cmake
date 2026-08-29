# Fetch the official upstream tag used by both the native and Hecate lanes.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO GNOME/libxml2
    REF "v2.15.3"
    SHA512 f65df793fca5e46552afbaa56b04c4774829a95e012a6dc4dc3d10e6884a6118e30a426e422516e1d21e91c4a1d34cb00a5cee61af35cab03c71fb9b5c09e138
    HEAD_REF master
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

# Match the validated production configuration. Programs, tests, Python, zlib,
# ICU, and readline are excluded. The glibc iconv path adds no external DSO.
set(XML2_OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DLIBXML2_WITH_PROGRAMS=OFF
    -DLIBXML2_WITH_TESTS=OFF
    -DLIBXML2_WITH_PYTHON=OFF
    -DLIBXML2_WITH_ZLIB=OFF
    -DLIBXML2_WITH_ICU=OFF
    -DLIBXML2_WITH_READLINE=OFF
    -DLIBXML2_WITH_ICONV=ON
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND XML2_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once to produce the unmodified libxml2 DSO and exact production
# compilation database consumed by TLC and HLR.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${XML2_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(XML2_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(XML2_LIBRARY "${XML2_BUILD}/libxml2.so.16.1.3")
    if(NOT EXISTS "${XML2_LIBRARY}")
        message(FATAL_ERROR "libxml2 input not found: ${XML2_LIBRARY}")
    endif()

    # Restrict HLR to the LibXml2 shared DSO target and export the precise 37-TU
    # database together with TLC and HLR statistics.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "CMakeFiles/LibXml2.dir/"
            --build "${XML2_BUILD}"
            --library "${XML2_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name xml2
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/include"
            --include "${XML2_BUILD}"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # Keep host-internal static callback tables raw and make the generated empty
    # initializer array valid under the production compiler.
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
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/libxml2)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/bin"
    "${CURRENT_PACKAGES_DIR}/debug/bin"
    "${CURRENT_PACKAGES_DIR}/debug/include"
    "${CURRENT_PACKAGES_DIR}/debug/share"
)
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
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/Copyright")
