# libcrc 2.0 validation (TLC Only) [ALL TESTS PASSED]

This recipe installs libcrc 2.0 and its upstream test through the pinned vcpkg overlay, generates TLC thunks, then executes the installed test in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/libcrc/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libcrc/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libcrc/run.sh --install-only /path/to/lorelei-devkit
```

The port builds the complete upstream `testall` program, including its CRC and NMEA translation units, and installs it under `tools/libcrc/upstream-tests`. The installed test reports `All tests succeeded` in both lanes with matching output. No source-tree rebuild or pure QEMU lane is used.
