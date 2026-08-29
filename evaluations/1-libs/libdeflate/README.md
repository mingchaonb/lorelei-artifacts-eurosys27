# libdeflate 1.26 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libdeflate 1.26 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libdeflate/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libdeflate/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libdeflate/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs the directed zlib-format roundtrip and all eight upstream registered unit-test executables in native and Hecate lanes. The evaluation CMake configuration exposes all eight tests per lane to CTest, for 16 registrations. The upstream set covers checksums, custom allocation callbacks, incomplete codes, invalid streams, literal-run-length overflow, overread protection, slow decompression, and trailing bytes. Success requires all nine processes in each lane to exit zero. The non-registered benchmark and command-line gzip integration scripts are outside this shared-library correctness suite. The mechanism is TLC only. It does not load or generate HLR extensions.
