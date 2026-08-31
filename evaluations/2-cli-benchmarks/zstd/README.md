# zstd 1.5.7 compression workload

[中文版](README.zh-CN.md)

This workload consecutively compresses 100 copies of the same deterministic 64 MiB input at level 3 with one worker. A single worker avoids turning the comparison into a guest thread-scheduling benchmark. Decompression and SHA-256 verification occur after timing.

```bash
./evaluations/2-cli-benchmarks/zstd/run.sh
REPETITIONS=1 ./evaluations/2-cli-benchmarks/zstd/run.sh --lanes native,qemu,blink,qemu-hecate
```

The runner calls `evaluations/1-libs/zstd/run.sh --install-only` when its native, guest, Hecate, or thunk artifacts are absent. It never rebuilds zstd from a source tree outside vcpkg.
