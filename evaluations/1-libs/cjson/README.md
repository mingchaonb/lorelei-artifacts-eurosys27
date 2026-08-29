# cJSON 1.7.19 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official cJSON 1.7.19 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/cjson/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/cjson/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/cjson/run.sh --install-only /path/to/lorelei-devkit
```

## Workload and scope

The workload covers nested object and array parsing, typed lookup, string access, array indexing, and malformed-input rejection. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The vcpkg port installs all 19 configured upstream core tests under `tools/cjson/upstream-tests`. The self-contained `run.sh` executes those installed tests after the directed workload in symmetric native and Hecate lanes. It never runs a pure-QEMU lane or rebuilds tests from an upstream source tree. The optional cJSON Utils DSO remains excluded.
