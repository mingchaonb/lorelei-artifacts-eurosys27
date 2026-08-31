# zlib 1.3.2 validation (TLC Only)

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs zlib 1.3.2 and its upstream runtime tests through the pinned vcpkg overlay, generates TLC thunks, then executes the installed tests in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/zlib/run.sh
./evaluations/1-libs/zlib/run.sh --install-only
```

The port installs `zlib_example`, `zlib_example64`, and `minigzip` under `tools/zlib/upstream-tests`. All three runtime cases pass in native and Hecate. Upstream CMake discovers 14 tests in this configuration. The remaining 12 are install and package-consumer build-system checks that invoke CMake to build new programs, so the installed-only runner explicitly excludes them. No source-tree rebuild or pure QEMU lane is used.
