# libaec 1.1.7 validation (TLC Only) [ALL TESTS PASSED]

This recipe builds the pinned official release as shared libraries for the AArch64 host and x86_64 guest, generates the workload-scoped TLC thunk, and runs the same directed public-API workload natively and through Hecate. The port has no `hlr` feature and the runner does not load an HLR extension.

## Commands

```bash
./evaluations/1-libs/libaec/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libaec/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libaec/run.sh --install-only /path/to/lorelei-devkit
```

Set `QEMU=/path/to/qemu-x86_64` when QEMU is not installed in the devkit.

## Workload and expected result

The workload compresses 32 deterministic 16-bit samples with preprocessing and then decompresses them through `libaec.so.0`. It requires byte-for-byte equality and also generates the independent `libsz.so.2` thunk.

Success reports a positive compressed size, 64 decoded bytes, and result zero in both lanes. No callback or shim is used.

## Upstream suite

The vcpkg port installs the complete configured CTest tree under `tools/libaec/upstream-tests`. The default `run.sh` executes all option, buffer, seeking, random-access, and sample-data tests in native and Hecate lanes after the directed workload. Both lanes pass 7/7. No pure-QEMU lane is run.
