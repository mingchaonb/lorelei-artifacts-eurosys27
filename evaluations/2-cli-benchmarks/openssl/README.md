# OpenSSL SHA-256 workload

[中文版](README.zh-CN.md)

This workload uses OpenSSL 3.0.22 to compute SHA-256 over 3 identical copies of a deterministic 256 MiB file. Like the other command-line workloads, it measures wall-clock execution time for a fixed command instead of running a fixed-duration throughput benchmark. Five native runs on the AE machine have a median of about 1.67 seconds.

The public command is:

```bash
openssl dgst -sha256 -binary -out OUTPUT data-256m.bin data-256m.bin data-256m.bin
```

The native and x86-64 CLIs, `libcrypto.so.3`, and `libssl.so.3` all come from the pinned `evaluations/1-libs/openssl` recipe. Hecate uses TLC thunks generated from the same AArch64 installation. `_common/prepare-inputs.sh` deterministically generates the input and records its SHA-256.

Each repetition writes 3 binary digests of 32 bytes each. The runner computes the expected bytes with Python and requires every completed lane output to match exactly. The primary results are the common lane TSV and JSON files in seconds.

The pinned Box64 version currently raises `SIGSEGV` while starting the OpenSSL 3.0.22 guest binary, so the plain Box64 and Box64 plus Hecate lanes are recorded as explicit exclusions. Blink is also excluded under the common Figure 17 policy if it exceeds 20 times native time. The runner retains the concrete reason in its result JSON and the exported CSV instead of presenting these paths as missing or successful data.

Run this workload:

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh
```

Prepare prerequisites without measuring:

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh --install-only
```
