include("${CMAKE_CURRENT_LIST_DIR}/../../tools/game-port-common.cmake")

set(game_dir "${CURRENT_PACKAGES_DIR}/tools/${PORT}/game")
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    ae_game_download(release_archive
        "SuperTux-v0.6.3.glibc2.29-x86_64.AppImage"
        "https://github.com/SuperTux/supertux/releases/download/v0.6.3/SuperTux-v0.6.3.glibc2.29-x86_64.AppImage"
        "7e0446ec959fd675c8b04ae9dbdd602e5b97bcc86880ab2c27bddc61d2f91a87a45436534aeb836854b3ddb27d7c9a3759807ce10fcef3500b82c3e57a223d33"
    )
    ae_game_download(com_err_archive
        "libcom-err2_1.45.5-2ubuntu1.2_amd64.deb"
        "https://archive.ubuntu.com/ubuntu/pool/main/e/e2fsprogs/libcom-err2_1.45.5-2ubuntu1.2_amd64.deb"
        "bc393368898a45679f5b36f56cbd33f01ffe8edea60974e91275bf89933432b91ffd25a3115bb49b6463a4747c2a615cb833c39281a182d5045770bbcc32107f"
    )
    ae_game_download(gpg_error_archive
        "libgpg-error0_1.37-1_amd64.deb"
        "https://archive.ubuntu.com/ubuntu/pool/main/libg/libgpg-error/libgpg-error0_1.37-1_amd64.deb"
        "dbec5dad3ac26410c0d87fd0e68f08e2b2d69167afed9546852c6c44ef07b199b3819e64d51d353d34d6561b185e115aa0f9c70ff784cbcc1bfc83a89e0a448f"
    )
    ae_game_download(p11_kit_archive
        "libp11-kit0_0.23.20-1ubuntu0.1_amd64.deb"
        "https://archive.ubuntu.com/ubuntu/pool/main/p/p11-kit/libp11-kit0_0.23.20-1ubuntu0.1_amd64.deb"
        "073b136c89a8cc6348f7bf0999489a645e14d51f55f58bc2e93724fcad625459e5f08e0904812978a17ffddc2286d874949ac40def39b02f2a547078a3c2b081"
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
    # AppImage stores its bundled runtime DSOs in the image's top-level lib
    # directory rather than below usr.  Put them in the private multiarch
    # directory already consumed by the game runner.
    file(INSTALL
        "${release_root}/lib/x86_64-linux-gnu/"
        DESTINATION "${game_dir}/usr/lib/x86_64-linux-gnu")
    ae_game_install_deb_libraries(
        "${com_err_archive}" "com-err-guest" "${game_dir}/usr/lib/x86_64-linux-gnu")
    ae_game_install_deb_libraries(
        "${gpg_error_archive}" "gpg-error-guest" "${game_dir}/usr/lib/x86_64-linux-gnu")
    ae_game_install_deb_libraries(
        "${p11_kit_archive}" "p11-kit-guest" "${game_dir}/usr/lib/x86_64-linux-gnu")
    set(copyright_file "${release_root}/usr/share/doc/supertux2/LICENSE.txt")
else()
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(native_deb_arch arm64)
        set(supertux_sha512 4d46fcd87e4959b207759a68699a27d5a5dd47b8a8172927d0d1c5b3a747cf5d29aa7660ce98902264fc7f5c70d67838168f81b853072f17712c226caf10a328)
        set(sdl_image_sha512 7cddc90d9fa3366b9d9a1477d840340850b9d576e915893826d2bf2514d6423a114a3517640925a178c26ecb8f50d46cb6f26728dfc67a5776d14d3990c0d06b)
        set(physfs_sha512 e0a3f6c4cce0a87f17e955ad36557df3e286c8af5712cccc90e5ae5f0f985fd1e2ab29d2c8ffb8b4fa35ccbf5556d2e7bd14bcefac29f70b86ea6ce1a4e2f87a)
        set(glew_sha512 35addf6cc61d9b2428cd74d64467caa01acf410bb04feb9eeb326bda3355e18c465d432a4176d5a1e3f109c980a6538bee2417027779d3cb1958071960ede705)
    elseif(VCPKG_TARGET_ARCHITECTURE STREQUAL "riscv64")
        set(native_deb_arch riscv64)
        set(supertux_sha512 41d9c23bca5d398d0e4bd4a225e77786b38a095cc7072ad3a584ed3e993ff32a06e89ab357aff4e04ebb3f8979ac0d3047a1f3dacae63a5a742583c651463b29)
        set(sdl_image_sha512 8389b801965ebb2edd0f3c7c7e5ff293e26435b9a1d82d0381cfac0615a37d21b2cb6189311d2b14abd71aeb8c9c53f8e543f8baf3539f9d756ba4735e9be6cb)
        set(physfs_sha512 b65d91561b2e57d8b7c62ad5dc8f28755efc17c52aa42db4ab78c7dafe76ecfa500ad9a0db240d8cd2ca6d7e7f604647b668d8ab5288c45997d3b74a496844f2)
        set(glew_sha512 9bd470b42f7e6a7049d5c6fd82497b7488919f2de6607990f4ca2a4a31ddb937d89e3e08dc443a0092f1a88c4b2a0bc7be8d08cf0b69077c1b6636c91b04e9d5)
    else()
        message(FATAL_ERROR "Unsupported native SuperTux architecture")
    endif()
    ae_game_download(native_archive
        "supertux_0.6.3-2build4_${native_deb_arch}.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/s/supertux/supertux_0.6.3-2build4_${native_deb_arch}.deb"
        "${supertux_sha512}"
    )
    ae_game_download(data_archive
        "supertux-data_0.6.3-2build4_all.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/s/supertux/supertux-data_0.6.3-2build4_all.deb"
        "f6edf0604953b93f0bc1f360710eded8e47e12a2ef93d3cf8f08edda33d12517ca4c45c1ec758b368959dd64af7e36bbfead076d45907a5b0326db7d04db5df4"
    )
    ae_game_download(sdl_image_archive
        "libsdl2-image-2.0-0_2.8.2+dfsg-1build2_${native_deb_arch}.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/libs/libsdl2-image/libsdl2-image-2.0-0_2.8.2%2bdfsg-1build2_${native_deb_arch}.deb"
        "${sdl_image_sha512}"
    )
    ae_game_download(physfs_archive
        "libphysfs1_3.0.2-6build2_${native_deb_arch}.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/libp/libphysfs/libphysfs1_3.0.2-6build2_${native_deb_arch}.deb"
        "${physfs_sha512}"
    )
    ae_game_download(glew_archive
        "libglew2.2_2.2.0-4build1_${native_deb_arch}.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/g/glew/libglew2.2_2.2.0-4build1_${native_deb_arch}.deb"
        "${glew_sha512}"
    )
    ae_game_download(roboto_archive
        "fonts-roboto-unhinted_0~20170802-3_all.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/f/fonts-roboto/fonts-roboto-unhinted_0~20170802-3_all.deb"
        "f65308a121b04a14a2e363abc344421284473cd1cb66e639584963d0409f9bab0aee5f999d84e13d28bdfa3c2327230f3f8df88f0047b2476351816b8ff2af01"
    )
    ae_game_download(nanum_archive
        "fonts-nanum_20200506-1_all.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/f/fonts-nanum/fonts-nanum_20200506-1_all.deb"
        "3626a9da47ba2df3f4ce807eb234aa426b92aedc5cd9b59b4ed9b95a737f9925736ba73d21c770ceb9f76edc0423fa887a3c8b964df2609dd8246bc76ae14dbb"
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
    # supertux-data declares these two fonts as Debian dependencies instead of
    # carrying them in its own archive.  Install them beside the other game
    # data so the native package remains self-contained.
    set(roboto_root "${CURRENT_BUILDTREES_DIR}/src/roboto-native")
    set(nanum_root "${CURRENT_BUILDTREES_DIR}/src/nanum-native")
    ae_game_extract_deb("${roboto_archive}" "${roboto_root}")
    ae_game_extract_deb("${nanum_archive}" "${nanum_root}")
    file(INSTALL
        "${roboto_root}/usr/share/fonts/truetype/roboto/unhinted/RobotoTTF/Roboto-Regular.ttf"
        "${nanum_root}/usr/share/fonts/truetype/nanum/NanumBarunGothic.ttf"
        DESTINATION "${game_dir}/usr/share/games/supertux2/fonts")
    # Ubuntu installs games under usr/games, while the upstream x64 AppImage
    # uses usr/bin.  Expose the same package layout to the evaluator on both
    # architectures without moving the Debian package's real executable.
    file(CHMOD "${game_dir}/usr/games/supertux2"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    file(MAKE_DIRECTORY "${game_dir}/usr/bin")
    file(CREATE_LINK "../games/supertux2" "${game_dir}/usr/bin/supertux2" SYMBOLIC)
    set(copyright_file "${native_root}/usr/share/doc/supertux/copyright")
endif()

# vcpkg's file installation copies contents but not the executable mode from
# the AppImage or Debian package extraction tree.
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    file(CHMOD "${game_dir}/usr/bin/supertux2"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${copyright_file}")
