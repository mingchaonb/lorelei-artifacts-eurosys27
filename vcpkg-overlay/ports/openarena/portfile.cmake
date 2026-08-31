include("${CMAKE_CURRENT_LIST_DIR}/../../tools/game-port-common.cmake")

ae_game_download(release_archive
    "openarena-0.8.8.zip"
    "https://downloads.sourceforge.net/project/oarena/openarena-0.8.8.zip"
    "9fa4dabe8a3428dc3cbec97f3b4d20c04569c14cdd00b60e6391c6dd61e310f246ff5ec97e7549821b3d6f5f94b140eb5411a2ddd83dafcad66937b7f78ea8dd"
)
set(release_root "${CURRENT_BUILDTREES_DIR}/src/release")
ae_game_extract_archive("${release_archive}" "${release_root}")
set(game_dir "${CURRENT_PACKAGES_DIR}/tools/${PORT}/game")
file(INSTALL "${release_root}/openarena-0.8.8/" DESTINATION "${game_dir}")
file(REMOVE_RECURSE
    "${game_dir}/__MACOSX"
    "${game_dir}/OpenArena.app"
    "${game_dir}/OpenArena 0.8.8 r28.app"
)
file(GLOB foreign_files "${game_dir}/*.dll" "${game_dir}/*.exe" "${game_dir}/*.i386")
file(REMOVE ${foreign_files})

if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
    ae_game_download(engine_archive
        "ioquake3_1.36+u20240217.7d711f8+dfsg-1build2_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/i/ioquake3/ioquake3_1.36%2bu20240217.7d711f8%2bdfsg-1build2_arm64.deb"
        "42984a530038f3cd3363715d9e6a7ad8b11d8c1f3cfc00313b1b69d082f0e03cacdeddd32548be9328010cd5b735db361b385869b04946cbeb5f1b7663109e37"
    )
    ae_game_download(native_archive
        "openarena_0.8.8+dfsg-7_arm64.deb"
        "https://ports.ubuntu.com/ubuntu-ports/pool/universe/o/openarena/openarena_0.8.8%2bdfsg-7_arm64.deb"
        "a5072ed24694b74b6bd140ffa882b213a93be8b7d284f670821b024d0c732aa59f1f0a539ba8cae386558033c1fb5c31149653c71cd0ee8f3bff8a8a268b405c"
    )
    set(engine_root "${CURRENT_BUILDTREES_DIR}/src/engine-native")
    set(native_root "${CURRENT_BUILDTREES_DIR}/src/native")
    ae_game_extract_deb("${engine_archive}" "${engine_root}")
    ae_game_extract_deb("${native_archive}" "${native_root}")
    file(COPY_FILE "${engine_root}/usr/lib/ioquake3/ioquake3" "${game_dir}/openarena.x86_64")
    file(GLOB renderer_modules "${engine_root}/usr/lib/ioquake3/renderer_*_aarch64.so")
    file(COPY ${renderer_modules} DESTINATION "${game_dir}")
    file(COPY "${native_root}/usr/lib/openarena/baseoa/" DESTINATION "${game_dir}/baseoa")
    file(COPY "${native_root}/usr/lib/openarena/missionpack/" DESTINATION "${game_dir}/missionpack")
endif()

# The upstream ZIP stores the Linux launchers without executable permission.
# Normalize their modes so the installed package can be launched directly.
foreach(launcher IN ITEMS openarena.x86_64 oa_ded.x86_64)
    if(EXISTS "${game_dir}/${launcher}")
        file(CHMOD "${game_dir}/${launcher}"
            PERMISSIONS
                OWNER_READ OWNER_WRITE OWNER_EXECUTE
                GROUP_READ GROUP_EXECUTE
                WORLD_READ WORLD_EXECUTE
        )
    endif()
endforeach()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug")
vcpkg_install_copyright(FILE_LIST "${release_root}/openarena-0.8.8/COPYING")
