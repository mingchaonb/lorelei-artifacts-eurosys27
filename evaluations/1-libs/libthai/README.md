# libthai 0.1.30 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe consumes the single shared `libdatrie` overlay dependency and builds libthai as a shared DSO. The port uses the host `trietool` while packaging so the target package contains the generated upstream dictionary. It runs the nine upstream character, cell, input, rendering, string, wide-character, sorting, and word-break tests. The sorting output must match the pinned expected file.

Documentation generation and static libraries are excluded. Public predicate macros are suppressed where necessary for thunk parsing. No second datrie port is created and no HLR extension is used.

Run `./evaluations/1-libs/libthai/run.sh` to install both architectures, generate the TLC thunk, and run all nine configured upstream tests in native and Hecate lanes. The vcpkg port installs the test binaries and sorting inputs under `tools/libthai/upstream-tests`. Pass `--install-only` to stop after package installation and thunk generation.
