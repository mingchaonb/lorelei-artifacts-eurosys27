vcpkg_download_distfile(
    ARCHIVE
    URLS "https://archive.ubuntu.com/ubuntu/pool/main/libx/libx11/libx11_${VERSION}.orig.tar.gz"
    FILENAME "libx11_${VERSION}.orig.tar.gz"
    SHA512 67575740356aecc6a7a4898e92ff1007aa6a44ff506d80fe577c1bdc3d64a900edf545cf3e082e9f17c25f4afe28e724145d5e82ae428bdc44348d368d9451a6
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

set(X11_OPTIONS
    --disable-specs
    # Avoid an executable configure probe that cannot run while cross compiling.
    # The Linux allocator contract permits non-NULL zero-size allocations, and
    # this setting is applied identically to native and Hecate package inputs.
    --disable-malloc0returnsnull
    --without-xmlto
    --without-fop
    --without-xsltproc
)

# libX11 generates key tables with makekeys during the build. This executable
# must use the evaluator host compiler even when the library itself targets the
# x86-64 guest. vcpkg-make otherwise substitutes a no-op cross-build probe.
find_program(X11_HOST_CC NAMES cc clang gcc REQUIRED)
list(APPEND X11_OPTIONS "CC_FOR_BUILD=${X11_HOST_CC}")

if(RUN_HLR)
    list(APPEND X11_OPTIONS "CFLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

vcpkg_make_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${X11_OPTIONS})

if(RUN_HLR)
    set(X11_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    find_program(BEAR bear REQUIRED)
    vcpkg_execute_required_process(
        COMMAND "${CMAKE_COMMAND}" -E env "PATH=$ENV{PATH}" "${BEAR}" --output "${X11_BUILD}/compile_commands.json" -- "${Z_VCPKG_MAKE}" -j "${VCPKG_CONCURRENCY}" V=1
        WORKING_DIRECTORY "${X11_BUILD}"
        LOGNAME bear-${TARGET_TRIPLET}
    )
    set(X11_INPUT_LIBRARY "${X11_BUILD}/src/.libs/libX11.so.6.4.0")
    if(NOT EXISTS "${X11_INPUT_LIBRARY}")
        message(FATAL_ERROR "libX11 input library not found: ${X11_INPUT_LIBRARY}")
    endif()
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}/src"
            --exclude-source "${SOURCE_PATH}/src/util/makekeys.c"
            --exclude-source "${SOURCE_PATH}/src/x11_xcb.c"
            --build "${X11_BUILD}"
            --library "${X11_INPUT_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name X11
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/include"
            --include "${SOURCE_PATH}/src"
            --include "${X11_BUILD}/include"
            --include "${CURRENT_INSTALLED_DIR}/include"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )
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
endif()

vcpkg_make_install()
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/include/X11/extensions")
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
