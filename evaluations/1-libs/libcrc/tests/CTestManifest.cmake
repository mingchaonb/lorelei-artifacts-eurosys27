foreach(mode IN ITEMS native hecate)
    add_test(NAME ${mode}.upstream-testall
        COMMAND "${TEST_LAUNCHER}" "${mode}" "${TEST_${mode}_ROOT}/workload")
endforeach()
