# libexif 0.6.26 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libexif 0.6.26 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libexif/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libexif/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libexif/run.sh --install-only /path/to/lorelei-devkit
```

## Workload and scope

The workload covers EXIF data and entry construction, byte order, data type, content ownership, tag initialization, lookup, and reference release. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The vcpkg port installs the executables, scripts, and data for all 15 configured upstream tests under `tools/libexif/upstream-tests`. The self-contained `run.sh` executes the installed suite in symmetric native and Hecate lanes. Fourteen pass and the optional `libfailmalloc` test is skipped according to upstream rules. No source-tree rebuild or pure-QEMU lane is used. Documentation, NLS, and shipped binaries remain excluded.
