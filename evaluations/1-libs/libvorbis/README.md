# libvorbis 1.3.7 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libvorbis/run.sh
./evaluations/1-libs/libvorbis/run.sh --reference --verbose
./evaluations/1-libs/libvorbis/run.sh --install-only
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload creates a stereo Vorbis encoder, adds a comment, initializes analysis state, submits sixteen silent frames, queries one analysis block, and clears all state.

Success reports two channels and 44100 Hz in both lanes. The recipe builds separate TLC thunks for `libogg.so.0`, `libvorbis.so.0`, and `libvorbisenc.so.2`, preserving their DSO boundaries.

## Upstream suite

The vcpkg fetch applies a CMake patch that registers and installs the upstream encode and decode round-trip suite under `tools/libvorbis/upstream-tests`. The default `run.sh` executes the suite in native and Hecate lanes after the directed workload. Both lanes pass the executable and all 528 internal checks. The high-level `libvorbisfile` DSO is evaluated by its separate port. No pure-QEMU lane is run.
