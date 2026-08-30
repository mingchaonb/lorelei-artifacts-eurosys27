# libtasn1 evaluation (TLC Only) [ALL TESTS PASSED]

This recipe pins libtasn1 4.21.0 and runs all 40 tests discovered by the selected upstream configuration. The production target is `libtasn1.so.6`. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. FILE ownership uses the shared libc shim, which does not change the TLC Only mechanism classification.

The vcpkg port installs the complete configured suite under `tools/libtasn1/upstream-tests`. This payload contains 9 fuzz regression executables, 24 regular executables, 7 shell tests, their fixtures, and the three installed command-line tools used by the shell tests. `run.sh` consumes only installed package files and does not rebuild tests from a source tree or vcpkg buildtree.

The pre-cleanup validation passed all 40 installed tests in both native and Hecate with identical classifications and no exclusions. The Hecate lane uses TLC plus the package-local libc shim for guest-owned `FILE` streams. It does not use HLR or run a pure QEMU lane.

The runner accepts one devkit path. `--install-only` stops after both packages are installed and audited. `--reference` writes append-only reference evidence. `--verbose` streams vcpkg preparation while preserving raw logs.

```bash
./run.sh --reference /path/to/lorelei-devkit
```
