get_filename_component(XORG_PORT_DIR "${CMAKE_PARENT_LIST_FILE}" DIRECTORY)
get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

set(ENV{ACLOCAL} "aclocal -I \"${CURRENT_INSTALLED_DIR}/share/xorg/aclocal/\"")
set(XORG_OPTIONS xorg_cv_malloc0_returns_null=yes --enable-malloc0returnsnull)
if(RUN_HLR)
    list(APPEND XORG_OPTIONS "CFLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

vcpkg_make_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS ${XORG_OPTIONS}
)

if(RUN_HLR)
    set(XORG_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    find_program(BEAR bear REQUIRED)
    vcpkg_execute_required_process(
        COMMAND "${CMAKE_COMMAND}" -E env "PATH=$ENV{PATH}" "${BEAR}"
            --output "${XORG_BUILD}/compile_commands.json" --
            "${Z_VCPKG_MAKE}" -j "${VCPKG_CONCURRENCY}" V=1
        WORKING_DIRECTORY "${XORG_BUILD}"
        LOGNAME bear-${TARGET_TRIPLET}
    )

    file(GLOB XORG_LIBRARY_CANDIDATES
        "${XORG_BUILD}/src/.libs/${XORG_LIBRARY_BASENAME}.so.*"
        "${XORG_BUILD}/.libs/${XORG_LIBRARY_BASENAME}.so.*"
    )
    set(XORG_INPUT_LIBRARY "")
    foreach(CANDIDATE IN LISTS XORG_LIBRARY_CANDIDATES)
        if(NOT IS_SYMLINK "${CANDIDATE}")
            set(XORG_INPUT_LIBRARY "${CANDIDATE}")
            break()
        endif()
    endforeach()
    if(NOT XORG_INPUT_LIBRARY)
        message(FATAL_ERROR "${XORG_LIBRARY_BASENAME} input library not found")
    endif()

    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}/src"
            --build "${XORG_BUILD}"
            --library "${XORG_INPUT_LIBRARY}"
            --port "${XORG_PORT_DIR}"
            --name "${XORG_HLR_NAME}"
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/include"
            --include "${SOURCE_PATH}/src"
            --include "${XORG_BUILD}/include"
            --include "${CURRENT_INSTALLED_DIR}/include"
            --include "/usr/include"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    if(EXISTS "${XORG_PORT_DIR}/patches/post-hlr.patch")
        vcpkg_find_acquire_program(GIT)
        vcpkg_execute_required_process(
            COMMAND "${GIT}" apply --check "${XORG_PORT_DIR}/patches/post-hlr.patch"
            WORKING_DIRECTORY "${SOURCE_PATH}"
            LOGNAME post-hlr-check
        )
        vcpkg_execute_required_process(
            COMMAND "${GIT}" apply "${XORG_PORT_DIR}/patches/post-hlr.patch"
            WORKING_DIRECTORY "${SOURCE_PATH}"
            LOGNAME post-hlr-apply
        )
    endif()
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
    file(INSTALL
        "${HLR_AUDIT_DIR}/thunk-stat/${XORG_LIBRARY_BASENAME}_HTL.so"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/thunk"
    )
    file(INSTALL
        "${HLR_AUDIT_DIR}/thunk-stat/x86_64"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/thunk"
    )
endif()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
