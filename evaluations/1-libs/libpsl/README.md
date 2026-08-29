# libpsl 0.21.5 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official libpsl 0.21.5 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libpsl/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libpsl/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libpsl/run.sh --install-only /path/to/lorelei-devkit
```

## Workload and scope

The workload covers builtin PSL exact, wildcard and exception rules plus registrable and unregistrable domain queries. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The build uses its builtin PSL and disables runtime IDNA. The vcpkg port installs all five API tests and three fuzz regression programs under `tools/libpsl/upstream-tests`. The self-contained `run.sh` executes all eight installed tests in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. CLI tools are not upstream tests.
