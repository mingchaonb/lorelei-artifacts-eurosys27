# libvorbisfile 1.3.7 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libvorbisfile/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libvorbisfile/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libvorbisfile/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload passes a deterministic non-Vorbis byte string through an `ov_callbacks` table to `ov_test_callbacks`. It requires a documented negative parse result after at least one guest read callback.

Success prints a negative result and a positive read count in both lanes. `libvorbisfile.so.3` remains a separate DSO and depends on the `libvorbis` and `libogg` packages. TLC handles the callback table without HLR.

## Exclusions

Valid-stream seeking, encoding, arbitrary media corpora, and interactive examples are excluded.
