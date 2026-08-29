# GNU libiconv 1.18 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official GNU libiconv 1.18 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libiconv/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libiconv/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libiconv/run.sh --install-only /path/to/lorelei-devkit
./evaluations/1-libs/libiconv/run-upstream.sh --reference /path/to/lorelei-devkit
```

## Workload and scope

The workload covers non-ASCII UTF-8 to UTF-16LE conversion through iconv_open, iconv, and iconv_close. It preloads the read-only version DATA shim and verifies guest-visible `EILSEQ` and `E2BIG` through the errno shim. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The default runner continues with the complete upstream `make check` suite. The standalone `run-upstream.sh` runs only that phase.

The upstream `make check` investigation additionally requires a host-only locale shim for the CLI substitution tests. The guest selects a UTF-8 locale, while the native library otherwise observes the host process C locale when resolving the GNU `char` encoding. The shim maps only `nl_langinfo(CODESET)` to `UTF-8` and is not loaded into the guest.
