# zstd 1.5.7 validation (TLC Only)

This recipe installs zstd 1.5.7 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the selected installed test in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/zstd/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/zstd/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/zstd/run.sh --install-only /path/to/lorelei-devkit
```

The port patches all four CMake registrations to build against the shared library and installs their executables and runtime data under `tools/zstd/upstream-tests`. The symmetric runner selects `fullbench` and `playTests.sh`. The test CLI is built without its asynchronous I/O worker while the shared library retains multithreading support. It excludes `fuzzer` and `zstreamtest` because their direct access to internal context state crashes through Hecate. The three dictionary-training sections of `playTests.sh` are also excluded because their buffer semantics are not supported across the thunk boundary. All other `playTests.sh` sections run in both lanes. No source-tree rebuild or pure QEMU lane is used.
