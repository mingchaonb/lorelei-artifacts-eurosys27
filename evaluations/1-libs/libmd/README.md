# libmd evaluation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

This recipe pins libmd 1.2.0 and validates the APIs used by seven digest executables. The production target is libmd.so.0. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. The guest thunk must preserve LIBMD_0.0, LIBMD_0.1, and LIBMD_0.2 symbol versions.

The runner reads the devkit from `LORELEI_DEVKIT`, defaulting to `.work/devkit` relative to the artifact repository. `--install-only` stops after the two shared packages have been built and audited. `--reference` writes append-only reference evidence. DATA, TLS, allocator ownership, callbacks, errno, symbol versions, SONAME, and dynamic dependencies are recorded in the generated audit even when a category has no workload hit.

The vcpkg port builds and installs all seven upstream digest tests. `run.sh` consumes only installed package payloads, runs native and Hecate, and never runs a pure QEMU lane. Expected success is exit status zero in both lanes with equivalent output.

```bash
./run.sh --reference
```
