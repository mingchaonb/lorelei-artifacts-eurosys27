# Fetch the exact upstream release used by this evaluation.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO curl/curl
    REF "curl-8_20_0"
    SHA512 452a76a238b6fa63d579eea37551cab9a02003fd542895905cf5ddc6b01b845697d30ebf5bf7b74db2c73113da3dcaf88d09093c9e2bdf8b4958690625d8800c
    HEAD_REF master
)

# The default package is the untouched baseline. The hlr feature adds the
# devkit headers, runs HLR, applies the reviewed generated-code adjustment,
# and rebuilds the same shared-library target.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

# Keep only the local HTTP functionality required by the directed workload.
# TLS, compression, authentication helpers, programs, and upstream tests do
# not belong to this claim-scoped DSO closure.
set(CURL_OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_STATIC_LIBS=OFF
    -DBUILD_CURL_EXE=OFF
    -DBUILD_TESTING=OFF
    -DBUILD_EXAMPLES=OFF
    -DBUILD_LIBCURL_DOCS=OFF
    -DBUILD_MISC_DOCS=OFF
    -DENABLE_CURL_MANUAL=OFF
    -DHTTP_ONLY=ON
    -DCURL_USE_OPENSSL=OFF
    -DCURL_USE_LIBSSH2=OFF
    -DCURL_USE_LIBPSL=OFF
    -DUSE_LIBIDN2=OFF
    -DCURL_DISABLE_LDAP=ON
    -DCURL_DISABLE_LDAPS=ON
    -DCURL_ZLIB=OFF
    -DCURL_BROTLI=OFF
    -DCURL_ZSTD=OFF
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
)
if(RUN_HLR)
    list(APPEND CURL_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Configure and build once to obtain the exact production compilation database
# and the unmodified libcurl DSO consumed by TLC and HLR.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${CURL_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(CURL_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(CURL_LIBRARY "${CURL_BUILD}/lib/libcurl.so.4.8.0")
    if(NOT EXISTS "${CURL_LIBRARY}")
        message(FATAL_ERROR "libcurl input not found: ${CURL_LIBRARY}")
    endif()

    # Filter the database to libcurl_shared, generate TLC metadata with static
    # callback replacement disabled, rewrite the sources, and save the audit.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "lib/CMakeFiles/libcurl_shared.dir/"
            --build "${CURL_BUILD}"
            --library "${CURL_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name curl
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}/include"
            --include "${CURL_BUILD}/include"
            --htl-arg=-fpermissive
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # Preserve the manual adaptation as an ordinary auditable patch rather
    # than relying on a private fork of curl.
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

    # Rebuild the same target from the rewritten sources.
    vcpkg_cmake_build()
endif()

# Install the library and headers into the lane-specific vcpkg prefix.
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/CURL)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/bin")

# Package the exact audit inputs and outputs so run.sh can copy them into the
# append-only evidence directory without reaching into vcpkg build trees.
if(RUN_HLR)
    file(INSTALL
        "${HLR_AUDIT_DIR}/HLR-Stat.json"
        "${HLR_AUDIT_DIR}/TLC-ThunkStat.json"
        "${HLR_AUDIT_DIR}/compile_commands.json"
        "${HLR_AUDIT_DIR}/hlr-sources.txt"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit"
    )
endif()

# Install the upstream license text used by the pinned source archive.
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
