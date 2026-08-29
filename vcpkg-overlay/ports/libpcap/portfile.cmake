vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO the-tcpdump-group/libpcap
    REF "libpcap-${VERSION}"
    SHA512 eb0a627cabdc4fab8f56e81065469a6fad713681d06c43e7a3080896cad3925e8b22c6957fcc0439e9229b3ebf21af55d22cd89c8494342e4188bb0ac193c7ab
    HEAD_REF master
)

vcpkg_find_acquire_program(BISON)
vcpkg_find_acquire_program(FLEX)
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

set(PCAP_OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_WITH_LIBNL=OFF
    -DDISABLE_AIRPCAP=ON
    -DDISABLE_BLUETOOTH=ON
    -DDISABLE_DAG=ON
    -DDISABLE_DBUS=ON
    -DDISABLE_DPDK=ON
    -DDISABLE_NETMAP=ON
    -DDISABLE_RDMA=ON
    -DDISABLE_SEPTEL=ON
    -DDISABLE_SNF=ON
    -DDISABLE_TC=ON
    -DDISABLE_LINUX_USBMON=ON
    -DENABLE_REMOTE=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    "-DLEX_EXECUTABLE=${FLEX}"
    "-DYACC_EXECUTABLE=${BISON}"
)
if(RUN_HLR)
    list(APPEND PCAP_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" DISABLE_PARALLEL_CONFIGURE OPTIONS ${PCAP_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(PCAP_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(PCAP_INPUT_LIBRARY "${PCAP_BUILD}/libpcap.so.1.10.6")
    if(NOT EXISTS "${PCAP_INPUT_LIBRARY}")
        message(FATAL_ERROR "libpcap input library not found: ${PCAP_INPUT_LIBRARY}")
    endif()
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --extra-source "${PCAP_BUILD}/grammar.c"
            --extra-source "${PCAP_BUILD}/scanner.c"
            --output-contains "CMakeFiles/pcap.dir/"
            --build "${PCAP_BUILD}"
            --library "${PCAP_INPUT_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name pcap
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}"
            --include "${PCAP_BUILD}"
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
    vcpkg_cmake_build()
endif()

vcpkg_cmake_install()
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/bin")
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
