# libvorbisfile 1.3.7 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libvorbisfile/run.sh
./evaluations/1-libs/libvorbisfile/run.sh --reference --verbose
./evaluations/1-libs/libvorbisfile/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload passes a deterministic non-Vorbis byte string through an `ov_callbacks` table to `ov_test_callbacks`. It requires a documented negative parse result after at least one guest read callback.

Success prints a negative result and a positive read count in both lanes. `libvorbisfile.so.3` remains a separate DSO and depends on the `libvorbis` and `libogg` packages. TLC handles the callback table without HLR.

## Upstream suite

The libvorbis 1.3.7 CMake configuration registers no dedicated `libvorbisfile` upstream tests. The vcpkg port still installs the configured test tree under `tools/libvorbisfile/upstream-tests`, and the default `run.sh` records the symmetric native and Hecate count as 0/0 after the directed callback workload passes in both lanes. No pure-QEMU lane is run.
