# Opus 1.5.2 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/opus/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/opus/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/opus/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload creates a 48 kHz mono encoder, sets a 64 kbit/s bitrate through the variadic CTL API, encodes one silent frame, reads the bitrate through another CTL request, and destroys the encoder.

Success reports a positive packet size and bitrate 64000 in both lanes. `Desc.h` provides TLC's request-dependent variadic extractor. No HLR or shim is used.

## Exclusions

Decoder, multistream, randomized corpus, private-symbol extension tests, programs, and the four-program upstream shared-library suite are excluded.
