# libspng 0.7.4 validation (TLC Only)

This recipe installs libspng 0.7.4 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libspng/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libspng/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libspng/run.sh --install-only /path/to/lorelei-devkit
```

The source patch builds and installs all executables and data for 208 upstream registrations under `tools/libspng/upstream-tests`. The symmetric runner selects 206 tests, including 41 expected-failure cases, and all 206 pass in native and Hecate. It explicitly excludes `images/ch1n3p04` and `images/ch2n3p08` because the current vcpkg libpng 1.6.58 differential oracle rejects those inputs in both lanes. Tests that pass `FILE *` use the TLC libc shim. No source-tree rebuild or pure QEMU lane is used.
