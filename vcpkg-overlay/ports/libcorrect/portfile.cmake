vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO quiet/libcorrect
    REF ee82e6673a806dfdf0a969b975ab36596ecc5401
    SHA512 a75593ca6c54c3cb4bbdb0bbf2c8aa98fa512e43aaa3434d5a6b23c60b976a0e4d7771999fc56883ff09f4352e2a697f576c5289f64b5bff5a5089eec06dd0ea
    PATCHES
        patches/explicit-static-targets.patch
        patches/deterministic-upstream-tests.patch
)

vcpkg_cmake_configure(SOURCE_PATH "${SOURCE_PATH}" OPTIONS -DHAVE_SSE=OFF -DHAVE_LIBFEC=OFF -DBUILD_SHARED_LIBS=OFF)
vcpkg_cmake_build(TARGET fec_shim_shared)
vcpkg_cmake_build(TARGET test_runners)
vcpkg_cmake_install()
set(TEST_BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/tests")
foreach(TEST_NAME convolutional_test_runner convolutional_shim_test_runner
        reed_solomon_test_runner reed_solomon_shim_interop_test_runner)
    file(INSTALL "${TEST_BUILD_DIR}/${TEST_NAME}"
        DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests"
        TYPE PROGRAM)
endforeach()
file(INSTALL "${SOURCE_PATH}/include/fec_shim.h" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
