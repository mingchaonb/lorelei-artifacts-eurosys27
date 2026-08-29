vcpkg_download_distfile(ARCHIVE
    URLS "https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.21.0.tar.gz"
    FILENAME "libtasn1-4.21.0.tar"
    SHA512 6a581c4c072b168bf29a0dec7e59a9329a798e392b7d1033791d0e3166a5d1164e2a7065373a84018d500a01563657900c318b1fd437c227c3174b754f9998d3
)
vcpkg_extract_source_archive(SOURCE_PATH ARCHIVE "${ARCHIVE}")
vcpkg_configure_make(SOURCE_PATH "${SOURCE_PATH}" OPTIONS --disable-static --disable-doc --disable-gcc-warnings)
vcpkg_install_make()
set(BUILD_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel")
foreach(SUBDIR fuzz tests)
    vcpkg_execute_required_process(COMMAND make -j${VCPKG_CONCURRENCY} check-am TESTS=
        WORKING_DIRECTORY "${BUILD_DIR}/${SUBDIR}" LOGNAME "build-upstream-tests-${SUBDIR}")
endforeach()
set(UPSTREAM_TEST_ROOT "${CURRENT_PACKAGES_DIR}/tools/${PORT}/upstream-tests")
set(FUZZ_TESTS
    libtasn1_array2tree_fuzzer
    libtasn1_parser2tree_fuzzer
    libtasn1_pkix_der_fuzzer
    libtasn1_gnutls_der_fuzzer
    asn1_get_length_ber_fuzzer
    asn1_get_length_der_fuzzer
    asn1_get_object_id_der_fuzzer
    asn1_decode_simple_ber_fuzzer
    asn1_decode_simple_der_fuzzer
)
set(REGULAR_TESTS
    Test_parser Test_tree Test_encoding Test_indefinite Test_errors Test_simple
    Test_overflow Test_strings Test_choice Test_encdec copynode coding-decoding2
    strict-der Test_choice_ocsp ocsp-basic-response octet-string coding-long-oid
    object-id-decoding spc_pe_image_data setof CVE-2018-1000654 reproducers
    object-id-encoding version
)
set(SCRIPT_TESTS
    crlf.sh threadsafety.sh decoding.sh decoding-invalid-x509.sh
    decoding-invalid-pkcs7.sh coding.sh parser.sh
)
foreach(TEST_NAME IN LISTS FUZZ_TESTS)
    file(INSTALL "${BUILD_DIR}/fuzz/${TEST_NAME}"
        DESTINATION "${UPSTREAM_TEST_ROOT}/fuzz" TYPE PROGRAM)
endforeach()
foreach(TEST_NAME IN LISTS REGULAR_TESTS)
    file(INSTALL "${BUILD_DIR}/tests/${TEST_NAME}"
        DESTINATION "${UPSTREAM_TEST_ROOT}/tests" TYPE PROGRAM)
endforeach()
foreach(TEST_NAME IN LISTS SCRIPT_TESTS)
    file(INSTALL "${SOURCE_PATH}/tests/${TEST_NAME}"
        DESTINATION "${UPSTREAM_TEST_ROOT}/tests" TYPE PROGRAM)
endforeach()
file(COPY "${SOURCE_PATH}/tests/" DESTINATION "${UPSTREAM_TEST_ROOT}/tests-source")
file(COPY "${SOURCE_PATH}/examples/" DESTINATION "${UPSTREAM_TEST_ROOT}/examples-source")
file(COPY "${SOURCE_PATH}/lib/" DESTINATION "${UPSTREAM_TEST_ROOT}/lib-source")
file(WRITE "${UPSTREAM_TEST_ROOT}/manifest.tsv" "")
foreach(TEST_NAME IN LISTS FUZZ_TESTS)
    file(APPEND "${UPSTREAM_TEST_ROOT}/manifest.tsv" "fuzz\t${TEST_NAME}\n")
endforeach()
foreach(TEST_NAME IN LISTS REGULAR_TESTS)
    file(APPEND "${UPSTREAM_TEST_ROOT}/manifest.tsv" "tests\t${TEST_NAME}\n")
endforeach()
foreach(TEST_NAME IN LISTS SCRIPT_TESTS)
    file(APPEND "${UPSTREAM_TEST_ROOT}/manifest.tsv" "tests\t${TEST_NAME}\n")
endforeach()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/COPYING")
vcpkg_fixup_pkgconfig()
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share" "${CURRENT_PACKAGES_DIR}/share/doc" "${CURRENT_PACKAGES_DIR}/share/man")
