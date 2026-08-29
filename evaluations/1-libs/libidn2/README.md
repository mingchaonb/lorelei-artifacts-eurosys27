# GNU Libidn2 2.3.8 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official GNU Libidn2 2.3.8 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libidn2/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libidn2/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libidn2/run.sh --install-only /path/to/lorelei-devkit
./evaluations/1-libs/libidn2/run-upstream.sh --reference /path/to/lorelei-devkit
```

## Workload and scope

The workload covers IDNA ASCII conversion for ASCII and non-ASCII labels through caller-owned buffers plus invalid Unicode rejection. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The build uses bundled libunistring. The default runner continues with all 15 configured upstream tests, including the three fuzz-harness executables. The standalone `run-upstream.sh` runs only that phase. Documentation and NLS remain excluded.
