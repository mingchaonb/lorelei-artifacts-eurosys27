# libspng 0.7.4 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libspng 0.7.4 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libspng/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libspng/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libspng/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs the directed API workload and the complete 208-test upstream Meson suite: 167 normal passes and 41 expected failures, with zero unexpected failures or skips in native, QEMU baseline, and Hecate lanes. The suite builds the pinned libpng 1.6.43 differential oracle from its verified release archive. Tests that pass `FILE *` use the repository's TLC libc shim. No HLR extension is loaded or generated.
