vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jedisct1/libsodium
    REF 93a7d0d41fe2e32409b5d00386946f491750b7de
    SHA512 0e3dadb26465cd514508ecf9060c47839c9ec3b421dd2c2a57f5c15dff5d7764302dd7711b4371e8b164241323fe2b9f8fa576bc466abae7c8098d8df707a939
)

vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}" AUTOCONFIG OPTIONS --disable-static --disable-asm)
vcpkg_install_make()
set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
execute_process(
    COMMAND make -s "--eval=print-tests:;@echo $(TESTS)" print-tests
    WORKING_DIRECTORY "${BUILD_DIR}/test/default"
    OUTPUT_VARIABLE TEST_NAMES
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY
)
separate_arguments(TEST_NAMES UNIX_COMMAND "${TEST_NAMES}")
vcpkg_execute_required_process(COMMAND make -j${VCPKG_CONCURRENCY} ${TEST_NAMES}
    WORKING_DIRECTORY "${BUILD_DIR}/test/default" LOGNAME build-upstream-tests)
foreach(TEST_NAME IN LISTS TEST_NAMES)
    if(EXISTS "${BUILD_DIR}/test/default/.libs/${TEST_NAME}")
        set(TEST_BINARY "${BUILD_DIR}/test/default/.libs/${TEST_NAME}")
    else()
        set(TEST_BINARY "${BUILD_DIR}/test/default/${TEST_NAME}")
    endif()
    file(INSTALL "${TEST_BINARY}"
        DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests/bin"
        TYPE PROGRAM)
endforeach()
file(INSTALL "${SOURCE_PATH}/test/default/" DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests/source")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
