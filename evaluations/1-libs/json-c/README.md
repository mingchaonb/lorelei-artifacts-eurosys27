# json-c 0.19-20260627 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official json-c 0.19-20260627 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/json-c/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/json-c/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/json-c/run.sh --install-only /path/to/lorelei-devkit
```

## Upstream test scope

Thread-local serialization is disabled. The vcpkg port installs all 28 tests registered by the configured upstream CTest suite under `tools/json-c/upstream-tests`. The self-contained `run.sh` executes those installed tests in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. The release ELF version script remains part of the built DSO.
