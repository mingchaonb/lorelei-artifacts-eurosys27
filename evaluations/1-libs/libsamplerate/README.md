# libsamplerate 0.2.2 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libsamplerate/run.sh
./evaluations/1-libs/libsamplerate/run.sh --reference --verbose
./evaluations/1-libs/libsamplerate/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload creates a callback-backed mono converter, returns one fixed eight-frame input block from a persistent guest callback, requests a 2.0 ratio, and validates produced frames and callback count.

Success reports a positive frame count, one callback invocation, and error zero in both lanes. TLC performs the callback replacement. No HLR or shim is used.

## Upstream suite

The vcpkg port installs the complete configured CTest tree under `tools/libsamplerate/upstream-tests`, including the FFTW comparison dependency. The default `run.sh` executes all tests in native and Hecate lanes after the directed workload. Both lanes pass 13/13. Audio-device examples are disabled build products. No pure-QEMU lane is run.
