# libdeflate 1.26 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs libdeflate 1.26 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libdeflate/run.sh
./evaluations/1-libs/libdeflate/run.sh --reference --verbose
./evaluations/1-libs/libdeflate/run.sh --install-only
```

The port installs all eight executables registered by upstream CMake under `tools/libdeflate/upstream-tests`. They cover checksums, allocation callbacks, incomplete codes, invalid streams, literal-run-length overflow, overread protection, slow decompression, and trailing bytes. All eight tests pass in native and Hecate. No source-tree rebuild or pure QEMU lane is used.
