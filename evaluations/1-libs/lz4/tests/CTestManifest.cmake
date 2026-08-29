foreach(mode IN ITEMS native hecate)
    add_test(NAME ${mode}.upstream-fuzzer
        COMMAND "${TEST_LAUNCHER}" "${mode}" "${TEST_${mode}_ROOT}/fuzzer" -s12345 -i150)
endforeach()
