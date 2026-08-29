# libsha1 evaluation (TLC Only) [ALL TESTS PASSED]

This recipe pins libsha1 0.1.0 and validates the APIs used by six upstream CUnit cases. The production target is libsha1.so. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. CUnit is a test-only dependency and is not part of the target ABI.

The runner accepts one devkit path. `--install-only` stops after the two shared packages have been built and audited. `--reference` writes append-only reference evidence. DATA, TLS, allocator ownership, callbacks, errno, symbol versions, SONAME, and dynamic dependencies are recorded in the generated audit even when a category has no workload hit.

The vcpkg port installs CUnit and builds and installs the complete six-case upstream test. `run.sh` consumes only installed package payloads, runs native and Hecate, and never runs a pure QEMU lane. Expected success is exit status zero in both lanes with equivalent output.

```bash
./run.sh --reference /path/to/lorelei-devkit
```
