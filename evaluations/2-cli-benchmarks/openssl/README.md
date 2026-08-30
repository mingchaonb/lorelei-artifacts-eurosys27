# OpenSSL SHA-256 workload

[中文版](README.zh-CN.md)

This workload runs OpenSSL 3.0.22's own `openssl speed` command and measures EVP SHA-256 throughput over a fixed 1 MiB buffer. Each invocation measures three seconds for greater stability while keeping a pure QEMU or pure Blink repetition below the command-line group's 180-second limit.

The public command is:

```bash
openssl speed -mr -elapsed -seconds 3 -bytes 1048576 -evp sha256
```

The native and x86-64 CLIs, `libcrypto.so.3`, and `libssl.so.3` all come from the pinned `evaluations/1-libs/openssl` recipe. Hecate uses TLC thunks generated from the same AArch64 installation. The `-mr` option emits a machine-readable `+F` throughput record, and the runner requires every repetition to produce that record successfully.

The primary metric is SHA-256 bytes per second, not the outer wall time of the `openssl speed` process. The `-seconds 3` option deliberately keeps every path active for approximately three seconds, so outer wall time is retained only for auditing. `throughput.tsv` stores every throughput sample. `throughput-summary.json` reports the median and range for each lane, Hecate speedup over the corresponding pure emulator, and Hecate throughput as a fraction of native.

Run this workload:

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh
```

Prepare prerequisites without measuring:

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh --install-only
```
