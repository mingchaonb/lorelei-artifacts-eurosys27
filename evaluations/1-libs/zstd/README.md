# zstd 1.5.7 validation (TLC Only)

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs zstd 1.5.7 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the selected installed test in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/zstd/run.sh
./evaluations/1-libs/zstd/run.sh --reference --verbose
./evaluations/1-libs/zstd/run.sh --install-only
```

The port builds and installs all four upstream CMake registrations and their runtime data under `tools/zstd/upstream-tests`. Native and Hecate symmetrically run three registrations and report `fuzzer` as a baseline skip: its fixed 30,000-iteration stress campaign is outside the AE functional scope. `fullbench` still exercises every registered function, using one timing iteration and a bounded sample because its default repetition is performance measurement rather than additional correctness coverage. The randomized `zstreamtest` uses a fixed seed and 100 functional iterations instead of its 10,000-iteration stress default. The test CLI is built without its asynchronous I/O worker while the shared library retains multithreading support. Narrow subtest exclusions cover guest callbacks in `zstreamtest` and the three dictionary-training sections of `playTests.sh`, because those pointer semantics are not supported across the thunk boundary. No source-tree rebuild or pure QEMU lane is used.
