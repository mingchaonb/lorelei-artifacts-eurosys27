# FFTW 3.3.10 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/fftw3/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/fftw3/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/fftw3/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload allocates two eight-element complex buffers, creates and executes one forward one-dimensional plan, validates selected output bins, and destroys the plan and buffers.

Success prints `fftw:1.000,0.000,0.000,-1.000` in both lanes. It exercises the double-precision public planner and execution API. It does not use the upstream bench metadata objects.

## Exclusions

Threads, Fortran, float and long-double variants, planner hooks, and the complete upstream suite are excluded. The port uses the official 3.3.10 release tarball because the Git tag omits release-generated files.
