# libdatrie 0.2.14 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libdatrie 0.2.14 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libdatrie/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libdatrie/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libdatrie/run.sh --install-only /path/to/lorelei-devkit
./evaluations/1-libs/libdatrie/run-upstream.sh --reference /path/to/lorelei-devkit
```

## Workload and scope

The workload covers trie creation, multiple stores, retrieval, deletion, missing-key lookup, and repeated synchronous enumeration callbacks. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The default runner continues with all 10 upstream test executables. The standalone `run-upstream.sh` runs only that phase. The trietool CLI remains excluded. The port name is stable for the libthai dependency.
