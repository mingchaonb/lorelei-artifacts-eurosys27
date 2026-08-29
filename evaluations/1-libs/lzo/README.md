# lzo 2.10 validation (TLC Only)

This recipe installs lzo 2.10 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/lzo/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/lzo/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/lzo/run.sh --install-only /path/to/lorelei-devkit
```

The port installs the five tests registered by upstream CMake under `tools/lzo/upstream-tests`. Four shared-library tests pass in both lanes, including the `-mall` 37-method tree sweep. `testmini` embeds miniLZO and therefore does not test the shared ABI. It is run only as a native build check and is explicitly excluded from Hecate. No source-tree rebuild or pure QEMU lane is used.
