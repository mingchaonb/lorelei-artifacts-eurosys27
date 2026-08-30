# libcerf 3.5 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libcerf/run.sh
./evaluations/1-libs/libcerf/run.sh --reference --verbose
./evaluations/1-libs/libcerf/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload evaluates the complex error function, Dawson function, and Voigt profile through the C ABI and checks finite values and basic numerical bounds.

Success prints identical nine-digit values in both lanes. The Clang patch only enables upstream's existing `__builtin_complex` construction path for complex infinity and NaN constants.

## Upstream suite

The vcpkg port installs the complete configured CTest tree under `tools/libcerf/upstream-tests`. The default `run.sh` executes all nine upstream C numerical tests in native and Hecate lanes after the directed workload. Both lanes pass 9/9. The C++ interface, examples, and manuals are disabled build products rather than tests in this configuration. No pure-QEMU lane is run.
