# libsha2 evaluation (TLC Only) [ALL TESTS PASSED]

This recipe pins libsha2 snapshot 565f650 and validates the APIs used by 37 upstream SHA-256 checks. The production target is libsha2.so. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. The upstream repository has no release tag.

The runner reads the devkit from `LORELEI_DEVKIT`, defaulting to `../lorelei-ae/build/install` relative to the artifact repository. `--install-only` stops after the two shared packages have been built and audited. `--reference` writes append-only reference evidence. DATA, TLS, allocator ownership, callbacks, errno, symbol versions, SONAME, and dynamic dependencies are recorded in the generated audit even when a category has no workload hit.

The vcpkg port builds and installs the complete 37-check upstream test. `run.sh` consumes only installed package payloads, runs native and Hecate, and never runs a pure QEMU lane. Expected success is exit status zero in both lanes with equivalent output.

```bash
./run.sh --reference
```
