# GNU libiconv 1.18 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe fetches the official GNU libiconv 1.18 release through the pinned vcpkg overlay, builds shared libraries and all configured upstream tests for AArch64 and x86-64, installs the tests with vcpkg, generates TLC thunks from those installed executables, and runs the same installed suite in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, load an HLR extension, or run a pure-QEMU lane.

## Commands

```bash
./evaluations/1-libs/libiconv/run.sh
./evaluations/1-libs/libiconv/run.sh --reference --verbose
./evaluations/1-libs/libiconv/run.sh --install-only
```

## Upstream test scope

The vcpkg port installs the complete upstream `make check` driver, helper programs, configured support files, and data under `tools/libiconv/upstream-tests`. The self-contained `run.sh` executes that installed suite in symmetric native and Hecate lanes. It does not configure or build a separate upstream source tree and never runs a pure-QEMU lane.

The upstream `make check` investigation additionally requires a host-only locale shim for the CLI substitution tests. The guest selects a UTF-8 locale, while the native library otherwise observes the host process C locale when resolving the GNU `char` encoding. The shim maps only `nl_langinfo(CODESET)` to `UTF-8` and is not loaded into the guest.
