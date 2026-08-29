add_test(NAME upstream-meson-native-and-hecate
    COMMAND "${UPSTREAM_SUITE}" "${TEST_DEVKIT}" "${TEST_QEMU}"
        "${TEST_WORK}" "${TEST_RESULT}" "${TEST_NATIVE_PREFIX}"
        "${TEST_GUEST_PREFIX}" "${TEST_REPO_ROOT}" "${TEST_NM}")
