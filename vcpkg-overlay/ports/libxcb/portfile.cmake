vcpkg_download_distfile(
    ARCHIVE
    URLS "https://archive.ubuntu.com/ubuntu/pool/main/libx/libxcb/libxcb_${VERSION}.orig.tar.gz"
    FILENAME "libxcb_${VERSION}.orig.tar.gz"
    SHA512 4099899c37fdda62a9a0883863ee9e50b5072e8f396ba6f4594965d9f1743fb6ea991974a99974c6f39bac14ce9aad5669fa633ac1ad2390280d613cc66eb00e
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")

set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

set(XCB_OPTIONS
    --disable-devel-docs
    --without-doxygen
    --disable-composite
    --disable-damage
    --disable-dpms
    --disable-dri2
    --disable-dri3
    --disable-ge
    --disable-glx
    --disable-present
    --disable-randr
    --disable-record
    --disable-render
    --disable-resource
    --disable-screensaver
    --disable-shape
    --disable-shm
    --disable-sync
    --disable-xevie
    --disable-xfixes
    --disable-xfree86-dri
    --disable-xinerama
    --disable-xinput
    --disable-xkb
    --disable-xprint
    --disable-selinux
    --disable-xtest
    --disable-xv
    --disable-xvmc
)
if(RUN_HLR)
    list(APPEND XCB_OPTIONS "CFLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

vcpkg_find_acquire_program(PYTHON3)
get_filename_component(PYTHON3_DIR "${PYTHON3}" DIRECTORY)
vcpkg_add_to_path("${PYTHON3_DIR}")

find_program(XLSTPROC NAMES "xsltproc${VCPKG_HOST_EXECUTABLE_SUFFIX}" PATHS "${CURRENT_HOST_INSTALLED_DIR}/tools/libxslt" PATH_SUFFIXES bin)
if(NOT XLSTPROC)
    message(FATAL_ERROR "libxcb requires xsltproc")
endif()
get_filename_component(XLSTPROC_DIR "${XLSTPROC}" DIRECTORY)
vcpkg_add_to_path("${XLSTPROC_DIR}")
set(ENV{XLSTPROC} "${XLSTPROC}")

if(DEFINED ENV{PYTHONPATH})
    set(ENV{PYTHONPATH} "${CURRENT_INSTALLED_DIR}/tools/python3/site-packages/${VCPKG_HOST_PATH_SEPARATOR}$ENV{PYTHONPATH}")
else()
    set(ENV{PYTHONPATH} "${CURRENT_INSTALLED_DIR}/tools/python3/site-packages/")
endif()

vcpkg_make_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${XCB_OPTIONS})

if(RUN_HLR)
    set(XCB_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    find_program(BEAR bear REQUIRED)
    vcpkg_execute_required_process(
        COMMAND "${CMAKE_COMMAND}" -E env "PATH=$ENV{PATH}" "${BEAR}" --output "${XCB_BUILD}/compile_commands.json" -- "${Z_VCPKG_MAKE}" -j "${VCPKG_CONCURRENCY}" V=1
        WORKING_DIRECTORY "${XCB_BUILD}"
        LOGNAME bear-${TARGET_TRIPLET}
    )
    set(XCB_INPUT_LIBRARY "${XCB_BUILD}/src/.libs/libxcb.so.1.1.0")
    if(NOT EXISTS "${XCB_INPUT_LIBRARY}")
        message(FATAL_ERROR "libxcb input library not found: ${XCB_INPUT_LIBRARY}")
    endif()
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}/src"
            --build "${XCB_BUILD}"
            --library "${XCB_INPUT_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name xcb
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/src"
            --include "${XCB_BUILD}/src"
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
