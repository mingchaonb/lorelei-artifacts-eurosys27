# Download SQLite's official release amalgamation. The archive's sqlite3.c and
# sqlite3.h match the historical unmodified AE baseline byte for byte.
vcpkg_download_distfile(
    SQLITE_ARCHIVE
    URLS "https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip"
    FILENAME "sqlite-amalgamation-3530400.zip"
    SHA512 fb0cc705e5eb4c690c9eb3b5a98652895b87745bcc2c379f044a315b6b79dda520c643f7c4e5a0fdeab63c79d5cbf40ff321d67bc7c4800b840d8003cb6686be
)
vcpkg_extract_source_archive_ex(
    OUT_SOURCE_PATH SOURCE_PATH
    ARCHIVE "${SQLITE_ARCHIVE}"
    SOURCE_BASE "3.53.4"
)

# Add the repository-owned minimal build description without changing any
# upstream SQLite source.
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")

# The default feature builds the official amalgamation unchanged. The hlr
# feature adds the devkit header, rewrites sqlite3.c, and rebuilds the DSO.
set(RUN_HLR OFF)
if("hlr" IN_LIST FEATURES)
    set(RUN_HLR ON)
    if(NOT DEFINED ENV{LORELEI_DEVKIT})
        message(FATAL_ERROR "The hlr feature requires LORELEI_DEVKIT")
    endif()
endif()

# Preserve the historical amalgamation command shape. In particular, avoid
# NDEBUG changing the single production translation unit's preprocessor view.
set(SQLITE_OPTIONS
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    "-DCMAKE_C_FLAGS_RELEASE=-O2 -g"
)
if(RUN_HLR)
    list(APPEND SQLITE_OPTIONS "-DCMAKE_C_FLAGS=-I$ENV{LORELEI_DEVKIT}/include")
endif()

# Build once to provide TLC and HLR with the exact official sqlite3 DSO and a
# compilation database containing one sqlite3.c command.
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS ${SQLITE_OPTIONS})
vcpkg_cmake_build()

if(RUN_HLR)
    set(SQLITE_BUILD "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
    set(SQLITE_LIBRARY "${SQLITE_BUILD}/libsqlite3.so.3.53.4")
    if(NOT EXISTS "${SQLITE_LIBRARY}")
        message(FATAL_ERROR "sqlite3 input not found: ${SQLITE_LIBRARY}")
    endif()

    # HLR sees only the official amalgamation, never SQLite's pre-amalgamation
    # internal source tree. The saved database must therefore contain one TU.
    set(HLR_AUDIT_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-hlr-audit")
    get_filename_component(OVERLAY_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
    vcpkg_find_acquire_program(PYTHON3)
    vcpkg_execute_required_process(
        COMMAND "${PYTHON3}" "${OVERLAY_ROOT}/tools/run-hlr.py"
            --devkit "$ENV{LORELEI_DEVKIT}"
            --source "${SOURCE_PATH}"
            --source-root "${SOURCE_PATH}"
            --output-contains "CMakeFiles/sqlite3.dir/sqlite3.c.o"
            --build "${SQLITE_BUILD}"
            --library "${SQLITE_LIBRARY}"
            --port "${CMAKE_CURRENT_LIST_DIR}"
            --name sqlite3
            --output "${HLR_AUDIT_DIR}"
            --include "${SOURCE_PATH}"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME hlr
    )

    # Move the generated header below SQLite's feature-test macros and retain
    # raw pointers in its large internal static callback tables.
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

    # Rebuild the identical sqlite3 target from the reviewed rewritten source.
    vcpkg_cmake_build()
endif()

# Install the shared library and public amalgamation headers.
vcpkg_cmake_install()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/bin")

# Package the filtered database and both tool statistics for the final evidence
# directory instead of depending on ephemeral vcpkg build trees.
if(RUN_HLR)
    file(INSTALL
        "${HLR_AUDIT_DIR}/HLR-Stat.json"
        "${HLR_AUDIT_DIR}/TLC-ThunkStat.json"
        "${HLR_AUDIT_DIR}/compile_commands.json"
        "${HLR_AUDIT_DIR}/hlr-sources.txt"
        DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/hlr-audit"
    )
endif()

# SQLite's source header carries its public-domain blessing.
file(INSTALL "${SOURCE_PATH}/sqlite3.h" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
