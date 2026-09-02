include("${CMAKE_CURRENT_LIST_DIR}/../../tools/game-port-common.cmake")

ae_game_download(release_archive
    "redeclipse_2.0.0_nix.tar.bz2"
    "https://github.com/redeclipse/base/releases/download/v2.0.0/redeclipse_2.0.0_nix.tar.bz2"
    "179a8177ddafefb09de38629c7cc15e8843cd49ad3580093c9f4243dd0d2d2fe095e8df770c2a8f3996d4e273822d6bc955acca73f8191266adb95a34beaf6dd"
)
set(release_root "${CURRENT_BUILDTREES_DIR}/src/release")
ae_game_extract_archive("${release_archive}" "${release_root}")
set(game_dir "${CURRENT_PACKAGES_DIR}/tools/${PORT}/game")
file(INSTALL "${release_root}/redeclipse-2.0.0/" DESTINATION "${game_dir}")
file(REMOVE_RECURSE
    "${game_dir}/bin/x86"
    "${game_dir}/bin/redeclipse.app"
    "${game_dir}/src"
)
file(GLOB foreign_files "${game_dir}/bin/amd64/*.dll")
file(REMOVE ${foreign_files})

# The release archive does not preserve executable mode bits after vcpkg's
# extraction. Restore them for both the packaged guest and rebuilt native lane.
file(CHMOD
    "${game_dir}/bin/amd64/redeclipse_linux"
    "${game_dir}/bin/amd64/redeclipse_server_linux"
    "${game_dir}/bin/amd64/cube2font_linux"
    "${game_dir}/bin/amd64/genkey_linux"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
)

if(NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    ae_game_download(source_archive
        "redeclipse-base-v2.0.0.tar.gz"
        "https://github.com/redeclipse/base/archive/refs/tags/v2.0.0.tar.gz"
        "1c0c24c5f64a0cfb252f7494ff3a49a7a1a873e762493703fcd9587c1b969967b6bf478971e0202f709109679fcc1d92b876410203a804d5f09708443adb4d3e"
    )
    set(source_root "${CURRENT_BUILDTREES_DIR}/src/native-source")
    ae_game_extract_archive("${source_archive}" "${source_root}")
    find_program(PKG_CONFIG pkg-config REQUIRED)
    find_program(MAKE make REQUIRED)
    set(pkg_config_path "${CURRENT_INSTALLED_DIR}/lib/pkgconfig:${CURRENT_INSTALLED_DIR}/share/pkgconfig")
    vcpkg_execute_build_process(
        COMMAND "${CMAKE_COMMAND}" -E env
            "PKG_CONFIG_PATH=${pkg_config_path}"
            "PKG_CONFIG=${PKG_CONFIG}"
            "WANT_STEAM="
            "WANT_DISCORD="
            "CXXFLAGS=-O3 -DNDEBUG"
            "${MAKE}" -j${VCPKG_CONCURRENCY} -C "${source_root}/base-2.0.0/src" client
        WORKING_DIRECTORY "${source_root}/base-2.0.0/src"
        LOGNAME "build-${PORT}-${TARGET_TRIPLET}"
    )
    file(COPY_FILE
        "${source_root}/base-2.0.0/src/redeclipse_linux"
        "${game_dir}/bin/amd64/redeclipse_linux"
    )
    file(CHMOD "${game_dir}/bin/amd64/redeclipse_linux"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${release_root}/redeclipse-2.0.0/doc/license.txt")
