# OpenSSL SHA-256 workload

[中文版](README.zh-CN.md)

This workload uses OpenSSL 3.0.22 to compute one SHA-256 digest over the concatenation of 3 identical copies of a deterministic 256 MiB file. Like the other command-line workloads, it measures wall-clock execution time for a fixed command instead of running a fixed-duration throughput benchmark.

The port installs a focused client at `tools/openssl/upstream-tests/sha256-ae`. The timed command is equivalent to:

```bash
sha256-ae OUTPUT data-256m.bin data-256m.bin data-256m.bin
```

The port also installs the original `openssl` command. QEMU-Hecate can execute its original `dgst` path. The focused client is used for the symmetric comparison because plain Box64 does not wrap the many unrelated OpenSSL 3 management interfaces imported by the monolithic command. This is a limitation of the comparator's wrapper coverage, not a Hecate execution failure.

The client calls `SHA256_Init`, `SHA256_Update`, and `SHA256_Final` from `libcrypto.so.3`. Its file input and output remain in guest libc, so no guest `FILE *` crosses the library boundary. The native and x86-64 clients and both `libcrypto.so.3` builds come from the pinned `evaluations/1-libs/openssl` recipe. Hecate uses TLC thunks generated from the same AArch64 installation. `_common/prepare-inputs.sh` deterministically generates the input and records its SHA-256.

Each repetition writes one 32-byte binary digest. The runner independently computes the digest with Python and requires every completed lane output to match exactly. The primary results are the common lane TSV and JSON files in seconds.

The workload runs all nine common lanes, including plain Box64 and Box64 plus Hecate. Plain Box64 uses its built-in OpenSSL wrapper for these three SHA-256 calls. It does not force `libcrypto.so.3` through x86-64 emulation. A non-native lane is excluded from Figure 17 only when it reaches the common cutoff of 20 times the native median, capped at 100 seconds. The result JSON and exported CSV retain that measured timeout rather than substituting a missing or successful value.

Run this workload:

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh
```

Prepare prerequisites without measuring:

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh --install-only
```
