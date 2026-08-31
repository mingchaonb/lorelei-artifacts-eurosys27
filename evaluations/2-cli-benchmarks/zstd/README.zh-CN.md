# zstd 1.5.7 压缩 workload

[English](README.md)

该 workload 使用一个 worker 和 level 3 连续压缩同一份确定性 64 MiB 输入 100 次。使用单 worker 可避免把对比变成 guest 线程调度 benchmark。解压和 SHA-256 校验位于计时之后。

```bash
./evaluations/2-cli-benchmarks/zstd/run.sh
./evaluations/2-cli-benchmarks/zstd/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/zstd/run.sh --lanes native,qemu,blink,qemu-hecate
```

当 native、guest、Hecate 或 thunk artifact 缺失时，runner 会调用 `evaluations/1-libs/zstd/run.sh --install-only`。它不会在 vcpkg 之外从源码树重新构建 zstd。
