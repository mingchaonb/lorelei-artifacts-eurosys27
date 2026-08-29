# xxhash 0.8.3 validation (TLC Only) [ALL TESTS PASSED]

This recipe installs xxhash 0.8.3 and its upstream test through the pinned vcpkg overlay, generates TLC thunks, then executes the installed test in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/xxhash/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/xxhash/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/xxhash/run.sh --install-only /path/to/lorelei-devkit
```

The source patch builds the complete official `tests/sanity_test.c` vector set against the shared library and installs it under `tools/xxhash/upstream-tests`. Upstream normally embeds `XXH_IMPLEMENTATION` in this test, so the patch removes that define while preserving its test logic, CLI helpers, and vectors. The installed test completes 49,948 checks in both lanes with matching output. No source-tree rebuild or pure QEMU lane is used.
