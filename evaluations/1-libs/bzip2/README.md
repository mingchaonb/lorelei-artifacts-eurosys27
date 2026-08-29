# bzip2 1.0.8 validation (TLC Only) [ALL TESTS PASSED]

This recipe installs bzip2 1.0.8 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/bzip2/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/bzip2/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/bzip2/run.sh --install-only /path/to/lorelei-devkit
```

The port builds the official CLI against the shared library and installs it with the upstream sample files under `tools/bzip2/upstream-tests`. The runner reproduces the complete upstream `make test` workload with three compression checks and three decompression checks in both lanes. All six byte comparisons pass in native and Hecate. No source-tree rebuild or pure QEMU lane is used.
