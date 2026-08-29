# json-c 0.19-20260627 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official json-c 0.19-20260627 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/json-c/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/json-c/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/json-c/run.sh --install-only /path/to/lorelei-devkit
```

## Workload and scope

The workload covers object and array parsing, typed lookup, string access, tokener state, and malformed-input error reporting. Success requires exit status zero and byte-identical output in native and Hecate lanes.

Thread-local serialization is disabled. The vcpkg port installs all 28 tests registered by the configured upstream CTest suite under `tools/json-c/upstream-tests`. The self-contained `run.sh` executes those installed tests in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. The release ELF version script remains part of the built DSO.
