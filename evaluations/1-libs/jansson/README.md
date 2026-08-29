# Jansson 2.15.1 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official Jansson 2.15.1 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/jansson/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/jansson/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/jansson/run.sh --install-only /path/to/lorelei-devkit
```

## Workload and scope

The workload covers nested values, array indexing, boolean, null and string access, reference release, and malformed-input location reporting. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The vcpkg port installs the executables and data for all 215 tests registered by the configured upstream CTest suite under `tools/jansson/upstream-tests`. The self-contained `run.sh` executes those installed tests in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. Examples and documentation remain excluded.
