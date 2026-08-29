# lzo 2.10 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official lzo 2.10 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/lzo/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/lzo/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/lzo/run.sh --install-only /path/to/lorelei-devkit
```

The recipe runs all five tests registered by upstream CMake, including the `-mall` 37-method tree sweep, plus the upstream alignment and checksum tests. Four registered tests and both additions cross the shared liblzo2 ABI in native and Hecate lanes. `testmini` is retained for suite completeness but embeds miniLZO and is explicitly reported as a non-DSO test. The mechanism is TLC only and does not load or generate HLR extensions.
