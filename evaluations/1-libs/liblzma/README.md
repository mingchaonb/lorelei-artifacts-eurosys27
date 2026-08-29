# liblzma 5.8.3 validation (TLC Only)

This recipe installs liblzma 5.8.3 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/liblzma/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/liblzma/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/liblzma/run.sh --install-only /path/to/lorelei-devkit
```

The port builds and installs all 19 tests registered by the official XZ 5.8.3 CMake configuration under `tools/liblzma/upstream-tests`. The symmetric run selects 13 tests, and all 13 pass in native and Hecate. It explicitly excludes `test_index`, `test_suffix.sh`, three generated compression cases, and `test_files.sh` because they currently fail through Hecate. No source-tree rebuild or pure QEMU lane is used.
