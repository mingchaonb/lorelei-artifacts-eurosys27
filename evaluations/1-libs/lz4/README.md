# lz4 1.10.0 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official lz4 1.10.0 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/lz4/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/lz4/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/lz4/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs the directed API workload and upstream `tests/fuzzer.c` for 150 deterministic cycles with seed 12345 in native and Hecate lanes. This is broad randomized coverage of normal, HC, dictionary, streaming, and frame APIs, but it is a bounded run of an intentionally unbounded upstream fuzzer rather than a claim that fuzzing is complete. Success requires both completion markers and zero exits. The mechanism is TLC only and does not load or generate HLR extensions.
