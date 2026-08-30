# libcorrect evaluation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

This recipe pins libcorrect snapshot ee82e667 and validates the APIs used by four convolutional and Reed-Solomon runners. The production target is libcorrect.so and libfec.so. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. Two independent ABI targets come from one source package, so the benchmark count is two.

The runner reads the devkit from `LORELEI_DEVKIT`, defaulting to `.work/devkit` relative to the artifact repository. `--install-only` stops after the two shared packages have been built and audited. `--reference` writes append-only reference evidence. DATA, TLS, allocator ownership, callbacks, errno, symbol versions, SONAME, and dynamic dependencies are recorded in the generated audit even when a category has no workload hit.

The vcpkg port builds and installs all four configured upstream test runners. `run.sh` consumes only installed package payloads, runs native and Hecate, and never runs a pure QEMU lane. Expected success is exit status zero in both lanes with equivalent output.

```bash
./run.sh --reference
```
