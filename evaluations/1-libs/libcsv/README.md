# libcsv 3.0.3 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libcsv 3.0.3 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libcsv/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libcsv/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libcsv/run.sh --install-only /path/to/lorelei-devkit
```

## Workload and scope

The workload covers strict incremental CSV parsing, quoted fields, LF and CRLF rows, repeated synchronous field and row callbacks, and allocator callbacks stored in the parser and invoked by later calls. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The vcpkg port installs the complete upstream `check_csv` executable under `tools/libcsv/upstream-tests`. The self-contained `run.sh` executes it in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane.
