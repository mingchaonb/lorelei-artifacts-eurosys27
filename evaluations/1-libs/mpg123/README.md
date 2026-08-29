# mpg123 1.33.7 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/mpg123/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/mpg123/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/mpg123/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload initializes libmpg123, creates a generic decoder handle, reads its flag parameter, destroys the handle, and shuts the library down.

Success prints `mpg123:0` and identical flags in both lanes. No audio device, input file, callback, or shim is used.

## Exclusions

Players, networking, CPU-specific decoder dispatch, device backends, and the six-program upstream suite are excluded.
