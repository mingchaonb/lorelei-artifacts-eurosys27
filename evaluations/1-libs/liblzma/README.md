# liblzma 5.8.3 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs liblzma 5.8.3 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/liblzma/run.sh
./evaluations/1-libs/liblzma/run.sh --reference --verbose
./evaluations/1-libs/liblzma/run.sh --install-only
```

The port builds and installs all 19 tests registered by the official XZ 5.8.3 CMake configuration under `tools/liblzma/upstream-tests`. All 19 pass in native and Hecate. Hecate loads the shared allocator libc shim for filter option buffers whose ownership crosses the thunk boundary. The 24 cases inside `test_index` are process-isolated in both lanes because retaining all opaque index state across the complete combined process triggers an internal Hecate fault, while every individual upstream case passes. No source-tree rebuild or pure QEMU lane is used.
