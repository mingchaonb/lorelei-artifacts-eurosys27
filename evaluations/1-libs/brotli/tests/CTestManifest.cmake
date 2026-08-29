set(roundtrip_inputs alice29.txt asyoulik.txt lcet10.txt plrabn12.txt encode.c dictionary.h decode.c)
foreach(mode IN ITEMS native hecate)
    foreach(input_name IN LISTS roundtrip_inputs)
        string(REPLACE "." "_" test_input "${input_name}")
        foreach(quality IN ITEMS 1 6 9 11)
            add_test(NAME ${mode}.roundtrip-${test_input}-q${quality}
                COMMAND "${TEST_CASE_DRIVER}" "${mode}" "${TEST_LAUNCHER}"
                    "${TEST_${mode}_ROOT}" "${TEST_${mode}_DATA}"
                    "${CMAKE_CURRENT_BINARY_DIR}/${mode}-brotli" roundtrip "${input_name}" "${quality}")
        endforeach()
    endforeach()
    foreach(input_name IN ITEMS empty ukkonooa)
        add_test(NAME ${mode}.compatibility-${input_name}
            COMMAND "${TEST_CASE_DRIVER}" "${mode}" "${TEST_LAUNCHER}"
                "${TEST_${mode}_ROOT}" "${TEST_${mode}_DATA}"
                "${CMAKE_CURRENT_BINARY_DIR}/${mode}-brotli" compatibility "${input_name}")
    endforeach()
endforeach()
