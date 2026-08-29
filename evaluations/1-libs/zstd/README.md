# zstd 1.5.7 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official zstd 1.5.7 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/zstd/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/zstd/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/zstd/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs the directed API workload and upstream's comprehensive `tests/playTests.sh` CLI correctness suite in native and Hecate lanes, using a zstd CLI dynamically linked to libzstd. The evaluation CMake configuration exposes one full-suite registration per lane to CTest. Upstream CMake's `fullbench`, `fuzzer`, and `zstreamtest` targets are explicitly excluded from the TLC ABI count because v1.5.7 hard-wires them to `libzstd_static`. `paramgrill` is a performance tuner. The mechanism is TLC only and does not load or generate HLR extensions.
