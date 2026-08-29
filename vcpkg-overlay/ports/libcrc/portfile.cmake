vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO lammertb/libcrc
    REF "v${VERSION}"
    SHA512 11d08c19fc321dce6a8a7304c74b5b9fbb1f94b36de98cae779ec705ffa40f8337365d77641d75b91293f596bd4ace5ca50338e609ca7554236aa4b82cdc29d0
    HEAD_REF master
)
file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS -DBUILD_SHARED_LIBS=ON)
vcpkg_cmake_install()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
