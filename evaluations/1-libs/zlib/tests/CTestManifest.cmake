foreach(mode IN ITEMS native hecate)
    foreach(test_name IN ITEMS zlib_example zlib_example64)
        add_test(NAME ${mode}.${test_name}
            COMMAND "${TEST_LAUNCHER}" "${mode}" "${TEST_${mode}_ROOT}/${test_name}")
        set_tests_properties(${mode}.${test_name} PROPERTIES
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${mode}-${test_name}")
        file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${mode}-${test_name}")
    endforeach()
    add_test(NAME ${mode}.minigzip
        COMMAND "${TEST_CASE_DRIVER}" "${mode}" "${TEST_LAUNCHER}"
            "${TEST_${mode}_ROOT}/minigzip" "${CMAKE_CURRENT_BINARY_DIR}/${mode}-minigzip")
endforeach()
