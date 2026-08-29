set(libdeflate_tests
    test_checksums
    test_custom_malloc
    test_incomplete_codes
    test_invalid_streams
    test_litrunlen_overflow
    test_overread
    test_slow_decompression
    test_trailing_bytes)
foreach(mode IN ITEMS native hecate)
    foreach(test_name IN LISTS libdeflate_tests)
        add_test(NAME ${mode}.${test_name}
            COMMAND "${TEST_LAUNCHER}" "${mode}" "${TEST_${mode}_ROOT}/${test_name}")
    endforeach()
endforeach()
