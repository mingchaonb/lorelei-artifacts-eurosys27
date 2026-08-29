# libsamplerate 0.2.2 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libsamplerate/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libsamplerate/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libsamplerate/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload creates a callback-backed mono converter, returns one fixed eight-frame input block from a persistent guest callback, requests a 2.0 ratio, and validates produced frames and callback count.

Success reports a positive frame count, one callback invocation, and error zero in both lanes. TLC performs the callback replacement. No HLR or shim is used.

## Exclusions

Examples, audio devices, optional FFTW comparisons, and the complete 13-test upstream configuration are excluded.
