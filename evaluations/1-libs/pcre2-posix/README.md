# PCRE2 POSIX 10.46 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official PCRE2 POSIX 10.46 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/pcre2-posix/run.sh
./evaluations/1-libs/pcre2-posix/run.sh --install-only
```

## Upstream test scope

The vcpkg port installs the registered upstream `pcre2posix_test` under `tools/pcre2-posix/upstream-tests`. The self-contained `run.sh` executes only that installed test in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. Only libpcre2-posix is the target. The 8-bit PCRE2 DSO is its host-side dependency. JIT, the core ABI, and utilities are excluded.
