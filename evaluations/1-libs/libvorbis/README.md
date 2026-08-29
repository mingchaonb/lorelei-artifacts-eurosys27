# libvorbis 1.3.7 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libvorbis/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libvorbis/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libvorbis/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload creates a stereo Vorbis encoder, adds a comment, initializes analysis state, submits sixteen silent frames, queries one analysis block, and clears all state.

Success reports two channels and 44100 Hz in both lanes. The recipe builds separate TLC thunks for `libogg.so.0`, `libvorbis.so.0`, and `libvorbisenc.so.2`, preserving their DSO boundaries.

## Exclusions

The high-level `libvorbisfile` DSO, full encode and decode round trip, arbitrary media, and upstream tests are excluded.
