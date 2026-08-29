# libsodium evaluation (TLC Only) [ALL TESTS PASSED]

This recipe pins libsodium 1.0.20 and validates the APIs used by the configured upstream make check suite. The production target is libsodium.so.26. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. Assembly dispatch is disabled so both lanes use the claimed portable implementation.

The runner accepts one devkit path. `--install-only` stops after the two shared packages have been built and audited. `--reference` writes append-only reference evidence. DATA, TLS, allocator ownership, callbacks, errno, symbol versions, SONAME, and dynamic dependencies are recorded in the generated audit even when a category has no workload hit.

The vcpkg port reads the configured upstream `TESTS` list and builds and installs all 80 executables and their fixtures. `run.sh` consumes only installed package payloads, runs native and Hecate, and never runs a pure QEMU lane. Expected success is all 80 tests passing in both lanes.

```bash
./run.sh --reference /path/to/lorelei-devkit
```
