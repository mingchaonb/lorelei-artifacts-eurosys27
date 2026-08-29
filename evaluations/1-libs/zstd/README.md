# zstd 1.5.7 validation (TLC Only)

This recipe installs zstd 1.5.7 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the selected installed test in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/zstd/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/zstd/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/zstd/run.sh --install-only /path/to/lorelei-devkit
```

The port builds and installs all four upstream CMake registrations and their runtime data under `tools/zstd/upstream-tests`. All four registered tests run symmetrically in native and Hecate. The test CLI is built without its asynchronous I/O worker while the shared library retains multithreading support. Narrow subtest exclusions cover caller-owned static contexts in `fuzzer`, guest callbacks in `zstreamtest`, and the three dictionary-training sections of `playTests.sh`, because those pointer semantics are not supported across the thunk boundary. No source-tree rebuild or pure QEMU lane is used.
