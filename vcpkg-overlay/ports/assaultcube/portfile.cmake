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
    find_program(MAKE make REQUIRED)
    find_program(CXX c++ REQUIRED)
    set(source_dir "${release_root}/source/src")
    set(client_includes
        "-I${CURRENT_INSTALLED_DIR}/include/SDL2 -I${CURRENT_INSTALLED_DIR}/include -I. -Ibot -I../enet/include")
    set(client_libraries
        "-L../enet/.libs -lenet -L${CURRENT_INSTALLED_DIR}/lib -Wl,-rpath,${CURRENT_INSTALLED_DIR}/lib -lX11 -lSDL2 -lSDL2_image -lz -lGL -lopenal -lvorbisfile")
    vcpkg_execute_build_process(
        COMMAND "${CMAKE_COMMAND}" -E env
            "${MAKE}" -j${VCPKG_CONCURRENCY} -C "${source_dir}"
                "CXX=${CXX}"
                "CLIENT_INCLUDES=${client_includes}"
                "CLIENT_LIBS=${client_libraries}"
                client server
        WORKING_DIRECTORY "${source_dir}"
        LOGNAME "build-${PORT}-${TARGET_TRIPLET}"
    )
    file(COPY_FILE "${source_dir}/ac_client" "${game_dir}/bin_unix/linux_64_client")
    file(COPY_FILE "${source_dir}/ac_server" "${game_dir}/bin_unix/linux_64_server")
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
