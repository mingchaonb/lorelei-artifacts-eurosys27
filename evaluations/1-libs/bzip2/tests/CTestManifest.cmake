foreach(mode IN ITEMS native hecate)
    add_test(NAME ${mode}.upstream-samples
        COMMAND "${TEST_CASE_DRIVER}" "${mode}" "${TEST_LAUNCHER}"
            "${TEST_${mode}_ROOT}/bzip2" "${TEST_${mode}_DATA}"
            "${CMAKE_CURRENT_BINARY_DIR}/${mode}-bzip2-suite")
endforeach()
