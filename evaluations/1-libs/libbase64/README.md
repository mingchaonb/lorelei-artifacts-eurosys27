# libbase64 0.5.2 validation (TLC Only) [ALL TESTS PASSED]

This recipe installs libbase64 0.5.2 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libbase64/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libbase64/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libbase64/run.sh --install-only /path/to/lorelei-devkit
```

The source patch builds both upstream test programs against the shared library and installs them under `tools/libbase64/upstream-tests`. `test_base64` covers known answers, invalid inputs, byte tables, streaming, and round trips. The upstream benchmark also completes in both lanes. Both installed tests pass in native and Hecate. No source-tree rebuild or pure QEMU lane is used.
