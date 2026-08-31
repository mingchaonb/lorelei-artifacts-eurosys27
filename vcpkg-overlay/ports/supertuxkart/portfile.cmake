include("${CMAKE_CURRENT_LIST_DIR}/../../tools/game-port-common.cmake")

set(game_dir "${CURRENT_PACKAGES_DIR}/tools/${PORT}/game")
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    ae_game_download(release_archive
        "SuperTuxKart-1.4-linux-x86_64.tar.xz"
        "https://github.com/supertuxkart/stk-code/releases/download/1.4/SuperTuxKart-1.4-linux-x86_64.tar.xz"
        "82fc32c288cc25fd316a54aab47e3e996c5a79c59dd9082fea4b527bc59d8365b1ba02b365dda747254faceb14d89441c58d24b2f4db92fda0b947ae468a38b6"
    )
    set(release_root "${CURRENT_BUILDTREES_DIR}/src/release")
    ae_game_extract_archive("${release_archive}" "${release_root}")
    file(INSTALL "${release_root}/SuperTuxKart-1.4-linux-x86_64/" DESTINATION "${game_dir}")
    set(copyright_file "${release_root}/SuperTuxKart-1.4-linux-x86_64/data/licenses.txt")
else()
    ae_game_download(native_archive
        "supertuxkart_1.4+dfsg-3ubuntu1_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/s/supertuxkart/supertuxkart_1.4%2bdfsg-3ubuntu1_arm64.deb"
        "a39ceb687cf92193243d1a41acb936f8e3040465380e507d12c6a3f111e36467822c442d90be3da6a14f938af97b1992d858e5c1f7e4318c707ca6009979c067"
    )
    ae_game_download(data_archive
        "supertuxkart-data_1.4+dfsg-3ubuntu1_all.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/s/supertuxkart/supertuxkart-data_1.4%2bdfsg-3ubuntu1_all.deb"
        "5d45e3572386c3a4b55c0d50ff3380c05d3a0f230aae637738b84d0d861c2c02c3f924536c189c0910c23feb3f5dccb30d2a4c394b5d4b36bb7ddb1d2d9b25fe"
    )
    ae_game_download(mcpp_archive
        "libmcpp0_2.7.2-5.1_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/m/mcpp/libmcpp0_2.7.2-5.1_arm64.deb"
        "ce243c9f8086770e0b828816cf5a16625c1ef3317c58cb0cdebdcd4e21e85872f62e81a439238005482f7e6a64cd826dc1a24ee08eddeb267427dafb4724412c"
    )
    ae_game_download(squish_archive
        "libsquish0_1.15-3_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/libs/libsquish/libsquish0_1.15-3_arm64.deb"
        "98f460ae97cb21cde14d5012d971eb0a7593bb78e2bb4a83c69d70e2ce25a4ef1de20d812cb2a2261c1356045751aa126db1943a504c18d31bd72519049e27d3"
    )
    ae_game_download(shaderc_archive
        "libshaderc1_2023.8-1build1_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/s/shaderc/libshaderc1_2023.8-1build1_arm64.deb"
        "03352fadb95ec4dd18acf75b37226c67723e858d003f36658bd0d3402f8a82df9b703081a86cdeb14a32c6213b0bec92e5f091b42dd331989cdd7fe7ca1683ac"
    )
    set(native_root "${CURRENT_BUILDTREES_DIR}/src/native")
    set(data_root "${CURRENT_BUILDTREES_DIR}/src/data-native")
    ae_game_extract_deb("${native_archive}" "${native_root}")
    ae_game_extract_deb("${data_archive}" "${data_root}")
    file(MAKE_DIRECTORY "${game_dir}/bin")
    file(COPY_FILE "${native_root}/usr/games/supertuxkart" "${game_dir}/bin/supertuxkart")
    file(INSTALL "${data_root}/usr/share/games/supertuxkart/" DESTINATION "${game_dir}/data")
    ae_game_install_deb_libraries("${mcpp_archive}" "mcpp-native" "${game_dir}/lib")
    ae_game_install_deb_libraries("${squish_archive}" "squish-native" "${game_dir}/lib")
    ae_game_install_deb_libraries("${shaderc_archive}" "shaderc-native" "${game_dir}/lib")
    set(copyright_file "${native_root}/usr/share/doc/supertuxkart/copyright")
endif()

# Restore executable modes after installing files from the release archives.
file(CHMOD "${game_dir}/bin/supertuxkart"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
if(EXISTS "${game_dir}/bin/supertuxkart-editor")
    file(CHMOD "${game_dir}/bin/supertuxkart-editor"
        PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${copyright_file}")
