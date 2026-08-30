# libspng 0.7.4 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs libspng 0.7.4 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libspng/run.sh
./evaluations/1-libs/libspng/run.sh --reference --verbose
./evaluations/1-libs/libspng/run.sh --install-only
```

The source patches build and install all executables and data for 208 upstream registrations under `tools/libspng/upstream-tests`. A compatibility adjustment prevents newer libpng releases from acting as the hIST metadata oracle when they reject that chunk, while preserving the remaining image and metadata comparisons. All 208 tests, including 41 expected-failure cases, pass in native and Hecate. Tests that pass `FILE *` use the TLC libc shim. No source-tree rebuild or pure QEMU lane is used.
