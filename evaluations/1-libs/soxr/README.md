# libsoxr 0.1.3 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/soxr/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/soxr/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/soxr/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload performs a scalar one-shot mono conversion from eight to sixteen samples and validates the returned frame count and finite output.

Success reports `ok` and more than eight output frames in both lanes. No callback or shim is used.

## Upstream suite

The vcpkg port installs the complete configured CTest tree under `tools/soxr/upstream-tests`. The default `run.sh` executes all vector and example-backed tests in native and Hecate lanes after the directed workload. Both lanes pass 9/9. SIMD, OpenMP, libsamplerate bindings, and libavutil integration are disabled in this configuration. No pure-QEMU lane is run.
