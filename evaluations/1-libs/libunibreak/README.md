# libunibreak 7.0 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

The workload runs the upstream `tests` executable in line, word, and grapheme modes using the release conformance vectors. Each mode must exit successfully in native and Hecate lanes.

Only the shared library and UTF-8 break APIs used by the workload are claimed. Documentation and static output are excluded. No HLR extension is used.

Run `./evaluations/1-libs/libunibreak/run.sh` to install both architectures, generate the TLC thunk, and run all three modes of the upstream test program in native and Hecate lanes. The vcpkg port installs the program and three conformance vectors under `tools/libunibreak/upstream-tests`. Pass `--install-only` to stop after package installation and thunk generation.
