# GNU Libidn2 2.3.8 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official GNU Libidn2 2.3.8 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/libidn2/run.sh
./evaluations/1-libs/libidn2/run.sh --reference --verbose
./evaluations/1-libs/libidn2/run.sh --install-only
```

## Upstream test scope

The build uses bundled libunistring. The vcpkg port installs all 15 configured upstream tests, including the CLI script and three fuzz-harness executables, under `tools/libidn2/upstream-tests`. Hecate loads the shared allocator libc shim so buffers returned by the host library are released on the same heap. A test-only port patch replaces `getline(FILE *)` in `test-IdnaTest-txt` with an equivalent bounded `fgets` loop because `getline` is outside that shim's supported stdio surface. The self-contained `run.sh` executes the installed suite in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. Documentation and NLS remain excluded.
