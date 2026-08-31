# mpg123 1.33.7 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/mpg123/run.sh
./evaluations/1-libs/mpg123/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload initializes libmpg123, creates a generic decoder handle, reads its flag parameter, destroys the handle, and shuts the library down.

Success prints `mpg123:0` and identical flags in both lanes. No audio device, input file, callback, or shim is used.

## Upstream suite

The vcpkg port builds and installs all six tests selected by the configured upstream Automake suite under `tools/mpg123/upstream-tests`. The default `run.sh` executes the same six tests in native and Hecate lanes after the directed workload. Both lanes pass 6/6. Players, networking, CPU-specific decoder dispatch, and device backends are disabled build features. No pure-QEMU lane is run.
