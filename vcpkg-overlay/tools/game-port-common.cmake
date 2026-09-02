function(ae_game_download out_var filename url sha512)
    set(download_urls "${url}")
    if("$ENV{USE_USTC_MIRROR}" STREQUAL "1" AND
       url MATCHES "^https://ports\\.ubuntu\\.com/ubuntu-ports/(.+)$")
        list(PREPEND download_urls
            "https://mirrors.ustc.edu.cn/ubuntu-ports/${CMAKE_MATCH_1}")
    endif()
    vcpkg_download_distfile(archive
        URLS ${download_urls}
        FILENAME "${filename}"
        SHA512 "${sha512}"
    )
    set(${out_var} "${archive}" PARENT_SCOPE)
endfunction()

function(ae_game_extract_archive archive destination)
    file(REMOVE_RECURSE "${destination}")
    file(MAKE_DIRECTORY "${destination}")
    file(ARCHIVE_EXTRACT INPUT "${archive}" DESTINATION "${destination}")
endfunction()

function(ae_game_extract_deb archive destination)
    find_program(DPKG_DEB dpkg-deb REQUIRED)
    file(REMOVE_RECURSE "${destination}")
    file(MAKE_DIRECTORY "${destination}")
    vcpkg_execute_required_process(
        COMMAND "${DPKG_DEB}" -x "${archive}" "${destination}"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME "extract-${PORT}-${TARGET_TRIPLET}"
    )
endfunction()

function(ae_game_install_deb_libraries archive extraction_name destination)
    set(extraction_root "${CURRENT_BUILDTREES_DIR}/src/${extraction_name}")
    ae_game_extract_deb("${archive}" "${extraction_root}")
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(deb_multiarch aarch64-linux-gnu)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "riscv64")
        set(deb_multiarch riscv64-linux-gnu)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
        set(deb_multiarch x86_64-linux-gnu)
    else()
        message(FATAL_ERROR "Unsupported Debian game architecture: ${VCPKG_TARGET_ARCHITECTURE}")
    endif()
    file(GLOB libraries
        "${extraction_root}/lib/${deb_multiarch}/*.so*"
        "${extraction_root}/usr/lib/${deb_multiarch}/*.so*")
    if(NOT libraries)
        message(FATAL_ERROR "No ${deb_multiarch} libraries found in ${archive}")
    endif()
    file(MAKE_DIRECTORY "${destination}")
    file(COPY ${libraries} DESTINATION "${destination}")
endfunction()

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
set(VCPKG_POLICY_SKIP_ARCHITECTURE_CHECK enabled)
set(VCPKG_POLICY_SKIP_ALL_POST_BUILD_CHECKS enabled)
set(VCPKG_POLICY_ALLOW_EMPTY_FOLDERS enabled)
set(VCPKG_FIXUP_ELF_RPATH OFF)
