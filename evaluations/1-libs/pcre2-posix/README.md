# PCRE2 POSIX 10.46 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official PCRE2 POSIX 10.46 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/pcre2-posix/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/pcre2-posix/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/pcre2-posix/run.sh --install-only /path/to/lorelei-devkit
./evaluations/1-libs/pcre2-posix/run-upstream.sh --reference /path/to/lorelei-devkit
```

## Workload and scope

The workload covers case-insensitive POSIX compilation, execution with whole-match and subgroup offsets, no-match handling, invalid-pattern compilation, caller-buffer error reporting, and release. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The default `run.sh` continues with the registered upstream `pcre2posix_test` after the directed workload. `run-upstream.sh` is the standalone upstream-only entry point. Both entries use native and Hecate lanes without a pure-QEMU lane. Only libpcre2-posix is the target. The 8-bit PCRE2 DSO is its host-side dependency. JIT, the core ABI, and utilities are excluded.
