# libdatrie 0.2.14 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libdatrie 0.2.14 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/libdatrie/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libdatrie/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libdatrie/run.sh --install-only /path/to/lorelei-devkit
```

## Upstream test scope

The vcpkg port installs all 10 upstream test executables under `tools/libdatrie/upstream-tests`. The self-contained `run.sh` executes them in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. The trietool CLI is not an upstream test. The port name is stable for the libthai dependency.
