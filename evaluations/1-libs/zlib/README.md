# zlib 1.3.2 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official zlib 1.3.2 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/zlib/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/zlib/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/zlib/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs the directed public-API roundtrip, both upstream CTest registrations that link the shared library (`zlib_example` and `zlib_example64`), and bidirectional `minigzip` coverage. The evaluation CMake configuration exposes these three dynamic-ABI cases per lane to CTest, for six registrations. Success requires zero exit status in both lanes, identical normalized example output, and successful native and Hecate minigzip roundtrips.

The upstream static-library duplicates, coverage instrumentation, and CMake install/package-consumer checks are excluded because they do not execute across the installed shared-library ABI. The mechanism is TLC only. It does not load or generate HLR extensions.
