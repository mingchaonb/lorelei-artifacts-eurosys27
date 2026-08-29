# GNU Libidn 1.43 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official GNU Libidn 1.43 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libidn/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libidn/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libidn/run.sh --install-only /path/to/lorelei-devkit
```

## Workload and scope

The workload covers Punycode encoding and decoding through caller-owned buffers, a non-ASCII roundtrip, and the insufficient-output error path. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The vcpkg port installs all 17 configured upstream API tests under `tools/libidn/upstream-tests`. The self-contained `run.sh` executes them in symmetric native and Hecate lanes without a source-tree rebuild or pure-QEMU lane. Documentation, NLS, and language bindings remain excluded.
