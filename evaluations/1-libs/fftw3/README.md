# FFTW 3.3.10 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/fftw3/run.sh
./evaluations/1-libs/fftw3/run.sh --reference --verbose
./evaluations/1-libs/fftw3/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload allocates two eight-element complex buffers, creates and executes one forward one-dimensional plan, validates selected output bins, and destroys the plan and buffers.

Success prints `fftw:1.000,0.000,0.000,-1.000` in both lanes. It exercises the double-precision public planner and execution API. It does not use the upstream bench metadata objects.

## Upstream suite

The vcpkg port installs the configured upstream test build under `tools/fftw3/upstream-tests`. The default `run.sh` executes both available scalar benchmark checks in native and Hecate lanes after the directed workload. Both lanes pass 2/2. Threads, Fortran, float, long-double, and SIMD variants are disabled in this configuration. No pure-QEMU lane is run.
