# OpenSSL SHA-256 workload

[中文版](README.zh-CN.md)

This workload uses OpenSSL 3.0.22 to compute SHA-256 over 3 identical copies of a deterministic 256 MiB file. Like the other command-line workloads, it measures wall-clock execution time for a fixed command instead of running a fixed-duration throughput benchmark.

The public command is:

```bash
openssl dgst -sha256 -binary -out OUTPUT data-256m.bin data-256m.bin data-256m.bin
```

The native and x86-64 CLIs, `libcrypto.so.3`, and `libssl.so.3` all come from the pinned `evaluations/1-libs/openssl` recipe. Hecate uses TLC thunks generated from the same AArch64 installation. `_common/prepare-inputs.sh` deterministically generates the input and records its SHA-256.

Each repetition writes 3 binary digests of 32 bytes each. The runner computes the expected bytes with Python and requires every completed lane output to match exactly. The primary results are the common lane TSV and JSON files in seconds.

The workload runs all nine common lanes, including plain Box64 and Box64 plus Hecate. A non-native lane is excluded from Figure 17 only when it reaches the common cutoff of 20 times the native median, capped at 100 seconds. The result JSON and exported CSV retain that measured timeout rather than substituting a missing or successful value.

Run this workload:

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh
```

Prepare prerequisites without measuring:

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh --install-only
```
