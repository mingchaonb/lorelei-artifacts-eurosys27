# libsndfile 1.2.2 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libsndfile/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libsndfile/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libsndfile/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload writes eight PCM16 samples to an in-memory WAV through five virtual-I/O callbacks, reopens the same buffer, reads the samples, and compares them byte for byte.

Success reports eight samples plus positive read and write callback counts in both lanes. TLC handles the persistent virtual-I/O callback table. No HLR or allocator shim is used.

## Exclusions

External FLAC, Ogg, Opus, Vorbis, and MPEG codecs remain disabled. The complete release test wrapper is outside this directed workload.
