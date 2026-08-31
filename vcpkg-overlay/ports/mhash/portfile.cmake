vcpkg_download_distfile(ARCHIVE
    URLS "https://downloads.sourceforge.net/project/mhash/mhash/0.9.9.9/mhash-0.9.9.9.tar.bz2"
    FILENAME "mhash-0.9.9.9.tar"
    SHA512 3b063d258cb0e7c2fa21ed30abae97bd6f3630ecd1cb4698afb826aa747555f3cf884828f24ac5e2b203730d0c7c0ecc9ef1e724ad9d85769a2f66128f3072eb
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
vcpkg_find_acquire_program(PYTHON3)
vcpkg_execute_required_process(COMMAND "${PYTHON3}" -c "import shutil,sysconfig,pathlib; d=pathlib.Path(r'${SOURCE_PATH}'); src=pathlib.Path('/usr/share/misc'); shutil.copy2(src/'config.guess',d/'config.guess'); shutil.copy2(src/'config.sub',d/'config.sub')" WORKING_DIRECTORY "${SOURCE_PATH}" LOGNAME update-gnu-config)
file(REMOVE
    "${SOURCE_PATH}/config.status"
    "${SOURCE_PATH}/libtool"
    "${SOURCE_PATH}/stamp-h1"
)
set(CONFIGURE_TRIPLET)
if(VCPKG_TARGET_ARCHITECTURE STREQUAL "x64")
    set(CONFIGURE_TRIPLET BUILD_TRIPLET "--host=x86_64-linux-gnu")
endif()
vcpkg_configure_make(
    SOURCE_PATH "${SOURCE_PATH}"
    ${CONFIGURE_TRIPLET}
    OPTIONS
        --disable-static
        --enable-shared
        ac_cv_func_malloc_0_nonnull=yes
        ac_cv_func_memcmp_working=yes
        "CPPFLAGS=-I${SOURCE_PATH}/include"
)
vcpkg_install_make()
set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
vcpkg_execute_required_process(COMMAND make -j${VCPKG_CONCURRENCY} check TESTS=
    WORKING_DIRECTORY "${BUILD_DIR}" LOGNAME build-upstream-tests)
set(TEST_DIR "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
file(MAKE_DIRECTORY "${TEST_DIR}")
foreach(TEST_NAME driver hmac_test keygen_test rest_test frag_test)
    file(INSTALL "${BUILD_DIR}/src/.libs/${TEST_NAME}" DESTINATION "${TEST_DIR}" TYPE PROGRAM)
endforeach()
file(INSTALL "${SOURCE_PATH}/src/hash_test.sh" DESTINATION "${TEST_DIR}" TYPE PROGRAM)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
