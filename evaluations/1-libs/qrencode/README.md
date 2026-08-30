# qrencode 4.1.1 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds only the shared QR encoding library with PNG and command-line tools disabled. The port installs and runs all 12 configured upstream algorithm tests in both native and Hecate lanes. No configured test is excluded.

The thunk surface is derived from the test executables. The compact public smoke surface in the port covers encoding and release. PNG output and the upstream CLI are excluded. No HLR feature or extension is used.

Run `./evaluations/1-libs/qrencode/run.sh` to install both architectures, generate the TLC thunk, and run all 12 upstream tests in native and Hecate lanes. The vcpkg port installs all test binaries, helper DSOs, internal test headers, and frame input under `tools/qrencode/upstream-tests`. Its source patches keep library-owned allocations and `errno` observations on the host side, while the shared allocator libc shim handles ownership that crosses the thunk boundary. Pass `--install-only` to stop after package installation and thunk generation.
