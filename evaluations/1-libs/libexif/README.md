# libexif 0.6.26 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libexif 0.6.26 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libexif/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libexif/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libexif/run.sh --install-only /path/to/lorelei-devkit
./evaluations/1-libs/libexif/run-upstream.sh --reference /path/to/lorelei-devkit
```

## Workload and scope

The workload covers EXIF data and entry construction, byte order, data type, content ownership, tag initialization, lookup, and reference release. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The default runner continues with the 15 configured upstream tests. Fourteen pass and the optional `libfailmalloc` test is skipped according to upstream rules. The standalone `run-upstream.sh` runs only that phase. Documentation, NLS, and shipped binaries remain excluded.
