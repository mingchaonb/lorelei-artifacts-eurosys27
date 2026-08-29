vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO maxmind/libmaxminddb
    REF "${VERSION}"
    SHA512 1ff3f22d40f9486089c598c0b57989879c006240f6782fe3ecd35f8bd0474323359f5ebafc000d046ec8d475da28411e632b7004bd6b3101ca2e4fed76f55af3
    HEAD_REF main
)
vcpkg_from_github(
    OUT_SOURCE_PATH LIBTAP_SOURCE_PATH
    REPO zorgnax/libtap
    REF b53e4ef5257f80e881762b6143834d8aae29da1a
    SHA512 4e8da92858fab7a3c04d86b3a62581301e520c907ee5284b7cc55e32affb4582f94f9c4326054462e361cda95ee4004083e2d52d3accdb2e03d062c1365c79c3
    HEAD_REF main
)
vcpkg_from_github(
    OUT_SOURCE_PATH DATABASE_SOURCE_PATH
    REPO maxmind/MaxMind-DB
    REF 819f226fbf8290c2b171ac077e6e050618dd3574
    SHA512 0d3bf40b95e6921f0d868a747dceca43ea52dac4759470756e67f8af6191900859f3bb2108b494d52a83b5a12d252469ffffd37dd349afa4f8dc5e2d2ab1cf13
    HEAD_REF main
)
file(COPY "${LIBTAP_SOURCE_PATH}/" DESTINATION "${SOURCE_PATH}/t/libtap")
file(COPY "${DATABASE_SOURCE_PATH}/" DESTINATION "${SOURCE_PATH}/t/maxmind-db")
vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS
    -DBUILD_SHARED_LIBS=ON
    -DBUILD_TESTING=ON
    -DMAXMINDDB_BUILD_BINARIES=OFF
)
vcpkg_cmake_install()
set(test_build "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/t")
set(test_names
    bad_pointers_t bad_search_tree_t basic_lookup_t data_entry_list_t data-pool-t
    data_types_t double_close_t dump_t gai_error_t get_value_pointer_bug_t
    get_value_t ipv4_start_cache_t ipv6_lookup_in_ipv4_t metadata_pointers_t
    metadata_t no_map_get_value_t overflow_bounds_t read_node_t version_t
    bad_databases_t bad_data_size_t bad_epoch_t bad_indent_t
    empty_container_metadata_t max_depth_t threads_t
)
set(test_install "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${test_install}/bin")
foreach(test_name IN LISTS test_names)
    file(INSTALL "${test_build}/${test_name}"
        DESTINATION "${test_install}/bin"
        USE_SOURCE_PERMISSIONS)
endforeach()
file(INSTALL "${test_build}/libtap.so"
    DESTINATION "${test_install}/lib"
    USE_SOURCE_PERMISSIONS)
file(COPY "${SOURCE_PATH}/t/maxmind-db"
    DESTINATION "${test_install}/t")
vcpkg_cmake_config_fixup(CONFIG_PATH lib/cmake/maxminddb)
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug" "${CURRENT_PACKAGES_DIR}/share/doc")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
