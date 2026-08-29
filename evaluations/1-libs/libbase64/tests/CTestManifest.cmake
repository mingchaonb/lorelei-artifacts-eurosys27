foreach(mode IN ITEMS native hecate)
    add_test(NAME ${mode}.upstream-correctness
        COMMAND "${TEST_LAUNCHER}" "${mode}" "${TEST_${mode}_ROOT}/workload")
    add_test(NAME ${mode}.upstream-benchmark
        COMMAND "${TEST_LAUNCHER}" "${mode}" "${TEST_${mode}_ROOT}/benchmark")
endforeach()
