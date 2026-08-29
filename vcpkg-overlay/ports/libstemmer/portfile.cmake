vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO snowballstem/snowball
    REF "v${VERSION}"
    SHA512 47a33f6319a728238b93b344a29c49b9aeb76bc8202b891da8134660be97d256e35980a25e557637c74fa6a8aff00b7e2d8e406d52b03233b71644989e4be9ac
    HEAD_REF master
)
vcpkg_from_github(
    OUT_SOURCE_PATH DATA_SOURCE_PATH
    REPO snowballstem/snowball-data
    REF a0ec0d0a2839ec885878868de20fcb63209d92b0
    SHA512 de068e9521e339595e0805fc4524a972a8862ccc47b4731f98913f4663bdd08e1608c28183d82af1de435ac6610b3a80cac19adfcc088119d6ebe4c319c8e41b
    HEAD_REF master
)
vcpkg_cmake_get_vars(cmake_vars_file)
include("${cmake_vars_file}")
vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}" SKIP_CONFIGURE)
file(COPY "${SOURCE_PATH}/" DESTINATION "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
configure_file("${SOURCE_PATH}/GNUmakefile" "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/Makefile" COPYONLY)
vcpkg_build_make(BUILD_TARGET libstemmer.a OPTIONS "CFLAGS=-O2 -fPIC")
vcpkg_build_make(BUILD_TARGET examples/stemwords.o OPTIONS "CFLAGS=-O2 -fPIC")
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib" "${CURRENT_PACKAGES_DIR}/include")
vcpkg_execute_required_process(
    COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}" -shared -Wl,-soname,libstemmer.so.0
        -Wl,--whole-archive "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/libstemmer.a"
        -Wl,--no-whole-archive -o "${CURRENT_PACKAGES_DIR}/lib/libstemmer.so.0.0.0"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
    LOGNAME link-shared
)
file(CREATE_LINK libstemmer.so.0.0.0 "${CURRENT_PACKAGES_DIR}/lib/libstemmer.so.0" SYMBOLIC)
file(CREATE_LINK libstemmer.so.0 "${CURRENT_PACKAGES_DIR}/lib/libstemmer.so" SYMBOLIC)
file(INSTALL "${SOURCE_PATH}/include/libstemmer.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
set(test_install "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${test_install}/bin")
vcpkg_execute_required_process(
    COMMAND "${VCPKG_DETECTED_CMAKE_C_COMPILER}"
        "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/examples/stemwords.o"
        "-L${CURRENT_PACKAGES_DIR}/lib" -lstemmer
        -o "${test_install}/bin/stemwords"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel"
    LOGNAME link-test-stemwords
)
file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/algorithms.mk"
    DESTINATION "${test_install}")
file(COPY "${DATA_SOURCE_PATH}/"
    DESTINATION "${test_install}/data")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
