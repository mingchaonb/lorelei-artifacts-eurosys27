# libcsv 3.0.3 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official libcsv 3.0.3 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/libcsv/run.sh
./evaluations/1-libs/libcsv/run.sh --reference --verbose
./evaluations/1-libs/libcsv/run.sh --install-only
```

## Upstream test scope

The vcpkg port installs the complete upstream `check_csv` executable under `tools/libcsv/upstream-tests`. The self-contained `run.sh` executes it in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane.
