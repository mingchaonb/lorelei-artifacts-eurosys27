# libdeflate 1.26 validation (TLC Only) [ALL TESTS PASSED]

This recipe installs libdeflate 1.26 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libdeflate/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libdeflate/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libdeflate/run.sh --install-only /path/to/lorelei-devkit
```

The port installs all eight executables registered by upstream CMake under `tools/libdeflate/upstream-tests`. They cover checksums, allocation callbacks, incomplete codes, invalid streams, literal-run-length overflow, overread protection, slow decompression, and trailing bytes. All eight tests pass in native and Hecate. No source-tree rebuild or pure QEMU lane is used.
