# xxhash 0.8.3 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official xxhash 0.8.3 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/xxhash/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/xxhash/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/xxhash/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs the complete official `tests/sanity_test.c` vector set in native and Hecate lanes. Upstream normally embeds `XXH_IMPLEMENTATION` into the test executable, so the runner removes only that define and dynamically links the unchanged test logic, CLI helpers, and official vectors to `libxxhash.so`. Success requires identical output and exit status zero in both lanes. Collision searches, benchmarks, shell tests for the excluded CLI, and generator programs are separate upstream tools rather than this shared-library sanity suite. The mechanism is TLC only. It does not load or generate HLR extensions.
