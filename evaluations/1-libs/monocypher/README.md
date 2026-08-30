# monocypher evaluation (TLC Only) [ALL TESTS PASSED]

This recipe pins monocypher 4.0.3 and validates the APIs used by the upstream test.out vector suite. The production target is libmonocypher.so.4. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. The core and optional Ed25519 implementation are in the tested DSO.

The runner reads the devkit from `LORELEI_DEVKIT`, defaulting to `../lorelei-ae/build/install` relative to the artifact repository. `--install-only` stops after the two shared packages have been built and audited. `--reference` writes append-only reference evidence. DATA, TLS, allocator ownership, callbacks, errno, symbol versions, SONAME, and dynamic dependencies are recorded in the generated audit even when a category has no workload hit.

The vcpkg port builds and installs the complete upstream vector test executable. `run.sh` consumes only installed package payloads, runs native and Hecate, and never runs a pure QEMU lane. Expected success is exit status zero in both lanes with equivalent output.

```bash
./run.sh --reference
```
