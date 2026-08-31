# libogg 1.3.6 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libogg/run.sh
./evaluations/1-libs/libogg/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload creates a stream with a fixed serial number, submits one seven-byte beginning-and-end packet, flushes one page, validates its header and body sizes, and clears the stream.

Success prints one produced page with a seven-byte body in both lanes. The test links the shared ABI and does not compile Ogg implementation sources into the executable.

## Upstream suite

The vcpkg port patches the shared build to retain and install the two upstream bitwise and framing selftests under `tools/libogg/upstream-tests`. The default `run.sh` executes both tests in native and Hecate lanes after the directed workload. Both lanes pass 2/2. No pure-QEMU lane is run.
