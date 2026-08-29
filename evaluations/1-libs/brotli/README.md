# brotli 1.2.0 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official brotli 1.2.0 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/brotli/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/brotli/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/brotli/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs the directed API workload, all 28 upstream roundtrip registrations, and two additional valid compatibility vectors. The four Canterbury inputs are fetched from the verified official v1.2.0 `testdata.txz` release asset. The CLI path dynamically exercises the common, encoder, and decoder DSOs in native and Hecate lanes. Fuzzers and benchmarks are excluded. The mechanism is TLC only and does not load or generate HLR extensions.
