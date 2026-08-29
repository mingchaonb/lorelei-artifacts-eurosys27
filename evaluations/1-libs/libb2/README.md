# libb2 evaluation (TLC Only) [ALL TESTS PASSED]

This recipe pins libb2 0.98.1 and runs all four upstream BLAKE2 known-answer executables selected by the shared-library configuration. The production target is `libb2.so.1`. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. OpenMP and architecture dispatch are disabled.

The vcpkg port installs all four tests under `tools/libb2/upstream-tests`. `run.sh` consumes only the installed packages and does not rebuild tests from a source tree or vcpkg buildtree.

Reference run `20260829T213928Z` passed all four tests in native and Hecate with identical output. There are no configured skips or failures. OpenMP and architecture-specific dispatch are disabled in both packages.

The runner accepts one devkit path. `--install-only` stops after both packages are installed and audited. `--reference` writes append-only reference evidence. `--verbose` streams vcpkg preparation while preserving raw logs. No pure QEMU lane is provided.

```bash
./run.sh --reference /path/to/lorelei-devkit
```
