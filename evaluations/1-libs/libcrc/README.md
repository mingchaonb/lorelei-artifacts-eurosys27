# libcrc 2.0 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libcrc 2.0 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libcrc/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libcrc/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libcrc/run.sh --install-only /path/to/lorelei-devkit
```

The workload dynamically links and runs the complete upstream `testall` program, including its CRC and NMEA test translation units. Success requires the upstream `All tests succeeded` result, identical normalized output, and exit status zero in both lanes. The mechanism is TLC only. It does not load or generate HLR extensions.
