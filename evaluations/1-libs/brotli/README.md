# brotli 1.2.0 validation (TLC Only) [ALL TESTS PASSED]

This recipe installs brotli 1.2.0 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/brotli/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/brotli/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/brotli/run.sh --install-only /path/to/lorelei-devkit
```

The port installs the upstream CLI and official release test data under `tools/brotli/upstream-tests`. The runner executes all 28 upstream roundtrip registrations and two compatibility-vector registrations in both lanes. All 30 tests pass in native and Hecate. The common DSO is exercised as the encoder and decoder dependency. No source-tree rebuild or pure QEMU lane is used.
