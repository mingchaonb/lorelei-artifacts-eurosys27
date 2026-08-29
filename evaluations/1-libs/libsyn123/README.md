# libsyn123 1.33.7 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libsyn123/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libsyn123/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libsyn123/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload creates a synthesis handle, converts minus six decibels to a linear factor and back, validates the round trip, and destroys the handle.

Success reports error zero and a recovered value of minus six decibels in both lanes. `libsyn123.so.0` is a separate DSO shipped by the mpg123 release. The `libmpg123` decoder DSO is evaluated separately.

## Exclusions

The upstream `volume` and `resample_total` programs, signal generation, and the decoder API are outside this directed workload.
