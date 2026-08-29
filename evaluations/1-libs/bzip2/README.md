# bzip2 1.0.8 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official bzip2 1.0.8 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/bzip2/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/bzip2/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/bzip2/run.sh --install-only /path/to/lorelei-devkit
```

The recipe retains the directed buffer roundtrip and reproduces the complete upstream `make test` workload with a dynamically linked copy of the official CLI source. It performs three compression checks and three decompression checks against the release samples. Success requires all six byte comparisons and the normalized SHA-256 output to match between native and Hecate. A TLC guest manifest maps guest standard streams to host standard streams. This remains TLC only and does not load or generate HLR extensions.
