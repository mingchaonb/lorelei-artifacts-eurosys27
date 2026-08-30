# libpsl 0.21.5 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official libpsl 0.21.5 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/libpsl/run.sh
./evaluations/1-libs/libpsl/run.sh --reference --verbose
./evaluations/1-libs/libpsl/run.sh --install-only
```

## Upstream test scope

The build uses its builtin PSL and disables runtime IDNA. The vcpkg port installs all five API tests and three fuzz regression programs under `tools/libpsl/upstream-tests`. The self-contained `run.sh` executes all eight installed tests in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. CLI tools are not upstream tests.
