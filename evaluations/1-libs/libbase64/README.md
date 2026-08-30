# libbase64 0.5.2 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs libbase64 0.5.2 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libbase64/run.sh
./evaluations/1-libs/libbase64/run.sh --reference --verbose
./evaluations/1-libs/libbase64/run.sh --install-only
```

The source patch builds both upstream test programs against the shared library and installs them under `tools/libbase64/upstream-tests`. `test_base64` covers known answers, invalid inputs, byte tables, streaming, and round trips. The upstream benchmark also completes in both lanes. Both installed tests pass in native and Hecate. No source-tree rebuild or pure QEMU lane is used.
