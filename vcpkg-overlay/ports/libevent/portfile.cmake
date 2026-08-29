vcpkg_from_github(OUT_SOURCE_PATH SOURCE_PATH REPO libevent/libevent REF "release-2.1.12-stable" SHA512 5d6c6f0072f69a68b190772d4c973ce8f33961912032cdc104ad0854c0950f9d7e28bc274ca9df23897937f0cd8e45d1f214543d80ec271c5a6678814a7f195e HEAD_REF master)
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()
set(EVENT_OPTIONS
    -DEVENT__LIBRARY_TYPE=SHARED
    -DEVENT__DISABLE_OPENSSL=ON
    -DEVENT__DISABLE_BENCHMARK=ON
    -DEVENT__DISABLE_TESTS=ON
    -DEVENT__DISABLE_REGRESS=ON
    -DEVENT__DISABLE_SAMPLES=ON
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND EVENT_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${EVENT_OPTIONS})
vcpkg_cmake_build()
if(RUN_HLR)
    set(EVENT_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(EVENT_LIBRARY "${EVENT_BUILD}/lib/libevent_core-2.1.so.7.0.1")
    if(NOT EXISTS "${EVENT_LIBRARY}")
        message(FATAL_ERROR "libevent_core input not found: ${EVENT_LIBRARY}")
    endif()
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}" --source "${SOURCE_PATH}" --source-root "${SOURCE_PATH}"
            --output-contains "CMakeFiles/event_core_shared.dir/" --build "${EVENT_BUILD}"
            --library "${EVENT_LIBRARY}" --port "${CMAKE_CURRENT_LIST_DIR}" --name event_core
            --output "${HLR_AUDIT_DIR}" --include "${SOURCE_PATH}/include" --include "${EVENT_BUILD}/include"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}" LOGNAME hlr
    )
    vcpkg_find_acquire_program(GIT)
    vcpkg_execute_required_process(COMMAND "${GIT}" apply --check "${CMAKE_CURRENT_LIST_DIR}/patches/post-hlr.patch" WORKING_DIRECTORY "${SOURCE_PATH}" LOGNAME post-hlr-check)
    vcpkg_execute_required_process(COMMAND "${GIT}" apply "${CMAKE_CURRENT_LIST_DIR}/patches/post-hlr.patch" WORKING_DIRECTORY "${SOURCE_PATH}" LOGNAME post-hlr-apply)
    vcpkg_cmake_build()
endif()
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/libevent)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/bin")
if(RUN_HLR)
    file(INSTALL "${HLR_AUDIT_DIR}/HLR-Stat.json" "${HLR_AUDIT_DIR}/TLC-ThunkStat.json" "${HLR_AUDIT_DIR}/compile_commands.json" "${HLR_AUDIT_DIR}/hlr-sources.txt" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit")
endif()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
