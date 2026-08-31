include("${CMAKE_CURRENT_LIST_DIR}/../../tools/game-port-common.cmake")

ae_game_download(release_archive
    "AssaultCube_v1.3.0.2_LockdownEdition_RC1.tar.bz2"
    "https://github.com/assaultcube/AC/releases/download/v1.3.0.2/AssaultCube_v1.3.0.2_LockdownEdition_RC1.tar.bz2"
    "d837e945681a44f76c5a17c651c0578d912fae1161b7d0fa3c5b06524c2639c8701b767c8a1aeb95d14066faa7c4ecb25f2d1ab845c10dce5cf655b59bbafcd9"
)
set(release_root "${CURRENT_BUILDTREES_DIR}/src/release")
ae_game_extract_archive("${release_archive}" "${release_root}")
set(game_dir "${CURRENT_PACKAGES_DIR}/tools/${PORT}/game")
file(INSTALL "${release_root}/" DESTINATION "${game_dir}")
file(REMOVE
    "${game_dir}/bin_unix/linux_32_client"
    "${game_dir}/bin_unix/linux_32_server"
)

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    ae_game_download(native_archive
        "assaultcube_1.3.0.2+dfsg-5_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/multiverse/a/assaultcube/assaultcube_1.3.0.2%2bdfsg-5_arm64.deb"
        "2da29498714d978a6416a1d63c3010f5ead54e067649eda487c0c08644c8a8a4e6b21ecb66abf5560825b3a791f7a2ff367bf72e67209671cd49ce88e8dcc767"
    )
    ae_game_download(sdl_image_archive
        "libsdl2-image-2.0-0_2.8.2+dfsg-1build2_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/libs/libsdl2-image/libsdl2-image-2.0-0_2.8.2%2bdfsg-1build2_arm64.deb"
        "7cddc90d9fa3366b9d9a1477d840340850b9d576e915893826d2bf2514d6423a114a3517640925a178c26ecb8f50d46cb6f26728dfc67a5776d14d3990c0d06b"
    )
    set(native_root "${CURRENT_BUILDTREES_DIR}/src/native")
    ae_game_extract_deb("${native_archive}" "${native_root}")
    file(COPY_FILE "${native_root}/usr/lib/games/assaultcube/ac_client" "${game_dir}/bin_unix/linux_64_client")
    file(COPY_FILE "${native_root}/usr/lib/games/assaultcube/ac_server" "${game_dir}/bin_unix/linux_64_server")
    ae_game_install_deb_libraries("${sdl_image_archive}" "sdl-image-native" "${game_dir}/lib")
endif()

foreach(launcher IN ITEMS linux_64_client linux_64_server)
    if(EXISTS "${game_dir}/bin_unix/${launcher}")
        file(CHMOD "${game_dir}/bin_unix/${launcher}"
            PERMISSIONS
                OWNER_READ OWNER_WRITE OWNER_EXECUTE
                GROUP_READ GROUP_EXECUTE
                WORLD_READ WORLD_EXECUTE
        )
    endif()
endforeach()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${release_root}/docs/package_copyrights.txt")
