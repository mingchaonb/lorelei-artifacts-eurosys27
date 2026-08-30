# libconfig 1.8.2 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official libconfig 1.8.2 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/libconfig/run.sh
./evaluations/1-libs/libconfig/run.sh --reference --verbose
./evaluations/1-libs/libconfig/run.sh --install-only
```

## Upstream test scope

Only the C API is claimed. The vcpkg port installs the upstream C test executable and data under `tools/libconfig/upstream-tests`. The self-contained `run.sh` executes all 16 C tests in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. The low-priority C++ API and examples remain excluded.
