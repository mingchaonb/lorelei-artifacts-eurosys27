include("${CMAKE_CURRENT_LIST_DIR}/../../tools/game-port-common.cmake")

set(game_dir "${CURRENT_PACKAGES_DIR}/tools/${PORT}/game")
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    ae_game_download(release_archive
        "SuperTux-v0.6.3.glibc2.29-x86_64.AppImage"
        "https://github.com/SuperTux/supertux/releases/download/v0.6.3/SuperTux-v0.6.3.glibc2.29-x86_64.AppImage"
        "7e0446ec959fd675c8b04ae9dbdd602e5b97bcc86880ab2c27bddc61d2f91a87a45436534aeb836854b3ddb27d7c9a3759807ce10fcef3500b82c3e57a223d33"
    )
    find_program(UNSQUASHFS unsquashfs REQUIRED)
    set(release_root "${CURRENT_BUILDTREES_DIR}/src/release")
    file(REMOVE_RECURSE "${CURRENT_BUILDTREES_DIR}/src")
    file(MAKE_DIRECTORY "${CURRENT_BUILDTREES_DIR}/src")
    vcpkg_execute_required_process(
        COMMAND "${UNSQUASHFS}" -o 189632 -d "${release_root}" "${release_archive}"
        WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
        LOGNAME "extract-${PORT}-${TARGET_TRIPLET}"
    )
    file(INSTALL "${release_root}/usr/" DESTINATION "${game_dir}/usr")
    set(copyright_file "${release_root}/usr/share/doc/supertux2/LICENSE.txt")
else()
    ae_game_download(native_archive
        "supertux_0.6.3-2build4_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/s/supertux/supertux_0.6.3-2build4_arm64.deb"
        "4d46fcd87e4959b207759a68699a27d5a5dd47b8a8172927d0d1c5b3a747cf5d29aa7660ce98902264fc7f5c70d67838168f81b853072f17712c226caf10a328"
    )
    ae_game_download(data_archive
        "supertux-data_0.6.3-2build4_all.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/s/supertux/supertux-data_0.6.3-2build4_all.deb"
        "f6edf0604953b93f0bc1f360710eded8e47e12a2ef93d3cf8f08edda33d12517ca4c45c1ec758b368959dd64af7e36bbfead076d45907a5b0326db7d04db5df4"
    )
    ae_game_download(sdl_image_archive
        "libsdl2-image-2.0-0_2.8.2+dfsg-1build2_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/libs/libsdl2-image/libsdl2-image-2.0-0_2.8.2%2bdfsg-1build2_arm64.deb"
        "7cddc90d9fa3366b9d9a1477d840340850b9d576e915893826d2bf2514d6423a114a3517640925a178c26ecb8f50d46cb6f26728dfc67a5776d14d3990c0d06b"
    )
    ae_game_download(physfs_archive
        "libphysfs1_3.0.2-6build2_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/libp/libphysfs/libphysfs1_3.0.2-6build2_arm64.deb"
        "e0a3f6c4cce0a87f17e955ad36557df3e286c8af5712cccc90e5ae5f0f985fd1e2ab29d2c8ffb8b4fa35ccbf5556d2e7bd14bcefac29f70b86ea6ce1a4e2f87a"
    )
    ae_game_download(glew_archive
        "libglew2.2_2.2.0-4build1_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/g/glew/libglew2.2_2.2.0-4build1_arm64.deb"
        "35addf6cc61d9b2428cd74d64467caa01acf410bb04feb9eeb326bda3355e18c465d432a4176d5a1e3f109c980a6538bee2417027779d3cb1958071960ede705"
    )
    set(native_root "${CURRENT_BUILDTREES_DIR}/src/native")
    set(data_root "${CURRENT_BUILDTREES_DIR}/src/data-native")
    ae_game_extract_deb("${native_archive}" "${native_root}")
    ae_game_extract_deb("${data_archive}" "${data_root}")
    file(INSTALL "${native_root}/usr/" DESTINATION "${game_dir}/usr")
    file(INSTALL "${data_root}/usr/" DESTINATION "${game_dir}/usr")
    ae_game_install_deb_libraries("${sdl_image_archive}" "sdl-image-native" "${game_dir}/lib")
    ae_game_install_deb_libraries("${physfs_archive}" "physfs-native" "${game_dir}/lib")
    ae_game_install_deb_libraries("${glew_archive}" "glew-native" "${game_dir}/lib")
    set(copyright_file "${native_root}/usr/share/doc/supertux/copyright")
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${copyright_file}")
