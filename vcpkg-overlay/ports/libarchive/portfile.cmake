# Fetch the official upstream release used by every evaluation lane.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libarchive/libarchive
    REF "v3.8.9"
    SHA512 c5d85564b70e3af24edc69f34829c70ba3abcaf042ba444e9344e54e594ac88a9cc22dcd21c806e2650f1ffde71e16aeaf70e9748d7ba124207ee832938656da
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

# Build the production shared library without command-line tools, the upstream
# test suite, crypto backends, XML parsers, or optional compression libraries.
set(ARCHIVE_OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DENABLE_TEST=OFF
    -DENABLE_TAR=OFF
    -DENABLE_CPIO=OFF
    -DENABLE_CAT=OFF
    -DENABLE_UNZIP=OFF
    -DENABLE_OPENSSL=OFF
    -DENABLE_MBEDTLS=OFF
    -DENABLE_NETTLE=OFF
    -DENABLE_LIBB2=OFF
    -DENABLE_LZ4=OFF
    -DENABLE_LZO=OFF
    -DENABLE_LZMA=OFF
    -DENABLE_ZSTD=OFF
    -DENABLE_ZLIB=OFF
    -DENABLE_BZip2=OFF
    -DENABLE_LIBXML2=OFF
    -DENABLE_EXPAT=OFF
    -DENABLE_WERROR=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND ARCHIVE_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once to produce the unmodified archive DSO and exact production
# compilation database consumed by TLC and HLR.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${ARCHIVE_OPTIONS})
vcpkg_cmake_build(TARGET archive)

if(RUN_HLR)
    set(ARCHIVE_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(ARCHIVE_LIBRARY "${ARCHIVE_BUILD}/libarchive/libarchive.so.13.8.9")
    if(NOT EXISTS "${ARCHIVE_LIBRARY}")
        message(FATAL_ERROR "libarchive input not found: ${ARCHIVE_LIBRARY}")
    endif()

    # Restrict HLR to the 123 production commands for the shared archive DSO.
    # The build also emits a static target from the same source closure.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "libarchive/CMakeFiles/archive.dir/"
            --build "${ARCHIVE_BUILD}"
            --library "${ARCHIVE_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name archive
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/libarchive"
            --include "${ARCHIVE_BUILD}"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # HLR recognizes libarchive's internal static callback tables as FDG. These
    # functions remain host-internal, so the reviewed patch retains raw pointers.
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

    # Rebuild only the rewritten shared target.
    vcpkg_cmake_build(TARGET archive)
endif()

# Install public headers, the DSO, pkg-config metadata, and the upstream license.
vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin" "${CURRENT_PACKAGES_DIR}/share/man")
if(VCPKG_TARGET_TRIPLET MATCHES "-ae$")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
endif()
foreach(header "include/archive.h" "include/archive_entry.h")
    vcpkg_replace_string("${CURRENT_PACKAGES_DIR}/${header}" "(!defined LIBARCHIVE_STATIC)" "0")
endforeach()

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
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
