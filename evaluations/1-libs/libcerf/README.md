# libcerf 3.5 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libcerf/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libcerf/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libcerf/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload evaluates the complex error function, Dawson function, and Voigt profile through the C ABI and checks finite values and basic numerical bounds.

Success prints identical nine-digit values in both lanes. The Clang patch only enables upstream's existing `__builtin_complex` construction path for complex infinity and NaN constants.

## Exclusions

The C++ interface, examples, manuals, and the nine-program upstream numerical suite are outside this directed workload.
