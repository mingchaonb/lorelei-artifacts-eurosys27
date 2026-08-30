# Jansson 2.15.1 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official Jansson 2.15.1 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/jansson/run.sh
./evaluations/1-libs/jansson/run.sh --reference --verbose
./evaluations/1-libs/jansson/run.sh --install-only
```

## Upstream test scope

The vcpkg port installs the executables and data for all 215 tests registered by the configured upstream CTest suite under `tools/jansson/upstream-tests`. The self-contained `run.sh` executes those installed tests in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. Examples and documentation remain excluded.
