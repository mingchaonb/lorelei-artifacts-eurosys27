# libexif 0.6.26 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official libexif 0.6.26 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/libexif/run.sh
./evaluations/1-libs/libexif/run.sh --reference --verbose
./evaluations/1-libs/libexif/run.sh --install-only
```

## Upstream test scope

The vcpkg port installs the executables, scripts, and data for all 15 configured upstream tests under `tools/libexif/upstream-tests`. The self-contained `run.sh` executes the installed suite in symmetric native and Hecate lanes. Fourteen pass and the optional `libfailmalloc` test is skipped according to upstream rules. No source-tree rebuild or pure-QEMU lane is used. Documentation, NLS, and shipped binaries remain excluded.
