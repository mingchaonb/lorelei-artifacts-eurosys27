vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO libsdl-org/sdl12-compat
    REF "release-${VERSION}"
    SHA512 d0e71e75f312402bf075f6553d9fd6493a3db9dd42719bb753287a35e6c40ee37c6092b157ff2384f3055400a3113645595d1269590cd50ea1e0c8f247240858
    HEAD_REF main
)

set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

set(SDL1_OPTIONS
    -DSDL12TESTS=OFF
    -DSDL12DEVEL=ON
    -DSTATICDEVEL=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND SDL1_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${SDL1_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(SDL1_INPUT_LIBRARY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/libSDL-1.2.so.1.2.68")
    if(NOT EXISTS "${SDL1_INPUT_LIBRARY}")
        message(FATAL_ERROR "SDL 1.2 input library not found: ${SDL1_INPUT_LIBRARY}")
    endif()

    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${CMAKE_CURRENT_LIST_DIR}/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --build "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
            --library "${SDL1_INPUT_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --output "${HLR_AUDIT_DIR}"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # SDL 1.2 compat passes its native AudioCallbackWrapper into the already
    # host-native SDL2 implementation. HLR cannot infer that this assignment is
    # an intra-host boundary and emits an FDG guest trampoline. Restore the
    # native function pointer after HLR so SDL2 never executes guest code as
    # AArch64. Keep the pass output otherwise unchanged and make drift fail.
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
    vcpkg_cmake_build()
endif()

vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE
    "${CURRENT_PACKAGES_DIR}/bin"
    "${CURRENT_PACKAGES_DIR}/debug"
    "${CURRENT_PACKAGES_DIR}/share/licenses"
)
if(RUN_HLR)
    file(INSTALL "${HLR_AUDIT_DIR}/HLRStat.json" "${HLR_AUDIT_DIR}/hlr-sources.txt"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit")
    file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/lorelei/ThunkDB.json"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
endif()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE.txt")
