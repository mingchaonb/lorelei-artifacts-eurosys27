# cJSON 1.7.19 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official cJSON 1.7.19 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/cjson/run.sh
./evaluations/1-libs/cjson/run.sh --install-only
```

## Upstream test scope

The vcpkg port installs all 19 configured upstream core tests under `tools/cjson/upstream-tests`. The self-contained `run.sh` executes only those installed tests in symmetric native and Hecate lanes. It never runs a pure-QEMU lane or rebuilds tests from an upstream source tree. The optional cJSON Utils DSO remains excluded.
