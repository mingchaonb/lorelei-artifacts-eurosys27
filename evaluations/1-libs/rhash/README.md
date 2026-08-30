# rhash evaluation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

This recipe pins RHash 1.4.6 and runs the complete upstream shared-library self-test selected by this configuration. The production target is `librhash.so.1`. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The Hecate lane uses TLC-generated GTL and HTL libraries. It does not enable an `hlr` feature, invoke LoreHLR, load either HLR extension, or claim APIs outside this workload. OpenSSL integration, gettext, and the CLI are excluded.

The vcpkg port builds `test_shared` and installs it under `tools/rhash/upstream-tests`. `run.sh` executes that installed binary directly in native and Hecate. It does not rebuild tests from a source tree or vcpkg buildtree.

The pre-cleanup validation passed the installed upstream test in both lanes with the identical output `All sums are working properly!`. There are no configured test failures or skips. OpenSSL integration, gettext, the CLI, and the static library are disabled in the shared-library configuration.

The runner reads the devkit from `LORELEI_DEVKIT`, defaulting to `.work/devkit` relative to the artifact repository. `--install-only` stops after both packages are installed and audited. `--reference` writes append-only reference evidence. `--verbose` streams vcpkg preparation while preserving raw logs. No pure QEMU lane is provided.

```bash
./run.sh --reference
```
