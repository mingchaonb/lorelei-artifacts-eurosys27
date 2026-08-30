# nettle evaluation (TLC Only)

This recipe pins nettle 3.10.2 and runs every test selected by the configured upstream `make check` suite. The production target is `libnettle.so.8`. Native AArch64 and x86-64 guest packages are built as shared libraries from the same official source input.

The two execution lanes are:

- Native AArch64 against the installed native package
- Hecate with the installed x86-64 tests, a TLC-generated GTL, and the native AArch64 library

The vcpkg port builds and installs the configured upstream suite under `tools/nettle/upstream-tests`. `run.sh` consumes only those installed tests and package payloads. It does not rebuild tests from a source tree or vcpkg buildtree. The package also carries the test manifest, fixtures, runner, TLC description, and guest-local read-only metadata needed by the suite.

The pre-cleanup validation reported identical native and Hecate classifications:

- 75 passed
- 5 skipped by the shared build configuration
- 0 failed

The shared configuration disables public-key support, assembler, OpenSSL integration, documentation, and static libraries. Consequently, the public-key helper and three RSA examples are skipped in both lanes. The x86 IBT probe is also skipped in both lanes because assembler is disabled. These are configuration exclusions rather than Hecate failures.

The runner accepts one devkit path. `--install-only` stops after both packages are installed and audited. `--reference` writes append-only reference evidence. `--verbose` streams vcpkg preparation while preserving the raw log files.

```bash
./run.sh --reference /path/to/lorelei-devkit
```
