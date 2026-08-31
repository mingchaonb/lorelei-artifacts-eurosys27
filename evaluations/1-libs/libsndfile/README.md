# libsndfile 1.2.2 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libsndfile/run.sh
./evaluations/1-libs/libsndfile/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload writes eight PCM16 samples to an in-memory WAV through five virtual-I/O callbacks, reopens the same buffer, reads the samples, and compares them byte for byte.

Success reports eight samples plus positive read and write callback counts in both lanes. TLC handles the persistent virtual-I/O callback table. No HLR or allocator shim is used.

## Upstream suite

The vcpkg port patches shared-library testing support and installs the complete configured CTest tree under `tools/libsndfile/upstream-tests`. The default `run.sh` executes the same 142 registered tests in native and Hecate lanes after the directed workload. Both lanes pass 142/142. The private-symbol-only `test_main` target is not registered for a shared build. External FLAC, Ogg, Opus, Vorbis, and MPEG codecs are disabled in this configuration. No pure-QEMU lane is run.
