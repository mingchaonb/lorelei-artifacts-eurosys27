foreach(mode IN ITEMS native hecate)
    add_test(NAME ${mode}.upstream-playTests
        COMMAND "${PLAY_DRIVER}" "${mode}" "${TEST_${mode}_SUITE}"
            "${TEST_${mode}_UPSTREAM}" "${TEST_${mode}_CLI}" "${TEST_${mode}_DATAGEN}"
            "${TEST_NATIVE_PREFIX}" "${TEST_GUEST_PREFIX}" "${TEST_HECATE_PREFIX}"
            "${TEST_THUNK_DIR}" "${TEST_RECIPE_DIR}" "${TEST_QEMU}" "${TEST_DEVKIT}")
endforeach()
