# lzo 2.10 validation (TLC Only)

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs lzo 2.10 and its upstream tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/lzo/run.sh
./evaluations/1-libs/lzo/run.sh --reference --verbose
./evaluations/1-libs/lzo/run.sh --install-only
```

The port installs the five tests registered by upstream CMake under `tools/lzo/upstream-tests`. Four shared-library tests pass in both lanes, including the `-mall` 37-method tree sweep. `testmini` embeds miniLZO and therefore does not test the shared ABI. It is run only as a native build check and is explicitly excluded from Hecate. No source-tree rebuild or pure QEMU lane is used.
