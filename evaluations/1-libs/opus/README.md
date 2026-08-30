# Opus 1.5.2 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/opus/run.sh
./evaluations/1-libs/opus/run.sh --reference --verbose
./evaluations/1-libs/opus/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload creates a 48 kHz mono encoder, sets a 64 kbit/s bitrate through the variadic CTL API, encodes one silent frame, reads the bitrate through another CTL request, and destroys the encoder.

Success reports a positive packet size and bitrate 64000 in both lanes. `Desc.h` provides TLC's request-dependent variadic extractor. No HLR or shim is used.

## Upstream suite

The vcpkg fetch patches CMake to retain shared-library-compatible tests and installs them under `tools/opus/upstream-tests`. The default `run.sh` executes all four tests registered by this shared configuration in native and Hecate lanes after the directed workload. Both lanes pass 4/4. The private-symbol extension target is not registered for a shared build because it cannot link against the public DSO. No pure-QEMU lane is run.
