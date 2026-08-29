# liblzma 5.8.3 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official liblzma 5.8.3 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/liblzma/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/liblzma/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/liblzma/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs the directed API workload and all 19 tests registered by the official XZ 5.8.3 default CMake configuration. Thirteen tests directly link liblzma and six exercise the dynamically linked `xz` and `xzdec` tools. The suite must pass natively and through Hecate. A pure QEMU lane is not run. The mechanism is TLC only and does not load or generate HLR extensions.
