# zstd 1.5.7 validation (TLC Only)

This recipe fetches the official zstd 1.5.7 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/zstd/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/zstd/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/zstd/run.sh --install-only /path/to/lorelei-devkit
```

The workload checks a deterministic public-API construction or roundtrip path. Success requires identical normalized output and exit status zero in both lanes. This claim excludes fuzzing, sanitizers, stress, concurrency, command-line tools, optional backends, and the complete upstream suite. The mechanism is TLC only. It does not load or generate HLR extensions.
