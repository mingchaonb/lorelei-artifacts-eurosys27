# libconfig 1.8.2 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libconfig 1.8.2 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libconfig/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libconfig/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libconfig/run.sh --install-only /path/to/lorelei-devkit
```

## Workload and scope

The workload covers C API parsing of scalar, group and array settings, typed and indexed lookup, string access, and malformed-input rejection from memory. Success requires exit status zero and byte-identical output in native and Hecate lanes.

Only the C API is claimed. The vcpkg port installs the upstream C test executable and data under `tools/libconfig/upstream-tests`. The self-contained `run.sh` executes all 16 C tests in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. The low-priority C++ API and examples remain excluded.
