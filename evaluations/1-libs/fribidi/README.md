# FriBidi 1.0.16 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official FriBidi 1.0.16 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/fribidi/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/fribidi/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/fribidi/run.sh --install-only /path/to/lorelei-devkit
```

## Upstream test scope

The Hecate lane preloads guest copies of the two exported read-only version pointers. The vcpkg port installs the configured upstream suite of six sample checks and two Unicode conformance executables under `tools/fribidi/upstream-tests`. The self-contained `run.sh` executes the installed suite in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. Documentation remains excluded.
