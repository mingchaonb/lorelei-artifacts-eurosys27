# FriBidi 1.0.16 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official FriBidi 1.0.16 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/fribidi/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/fribidi/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/fribidi/run.sh --install-only /path/to/lorelei-devkit
./evaluations/1-libs/fribidi/run-upstream.sh --reference /path/to/lorelei-devkit
```

## Workload and scope

The workload covers logical-to-visual conversion for fixed left-to-right and Hebrew right-to-left sequences, mapping arrays, embedding levels, and read-only version DATA. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The Hecate lane preloads guest copies of the two exported read-only version pointers. The default runner then executes the configured upstream suite of six sample checks and two Unicode conformance executables. The standalone `run-upstream.sh` runs only that upstream phase. Documentation remains excluded.
