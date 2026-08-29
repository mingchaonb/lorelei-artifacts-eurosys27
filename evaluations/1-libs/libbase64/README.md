# libbase64 0.5.2 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libbase64 0.5.2 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libbase64/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libbase64/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libbase64/run.sh --install-only /path/to/lorelei-devkit
```

The recipe dynamically links and runs both upstream registered tests in the scalar configuration. The evaluation CMake configuration exposes both programs per lane to CTest, for four registrations. `test_base64` covers known answers, invalid inputs, byte tables, streaming, and round trips. Its normalized output must match between lanes. The upstream `benchmark` must complete and report plain encode and decode measurements in both lanes, while architecture-dependent timings are retained without direct comparison. The mechanism is TLC only. It does not load or generate HLR extensions.
