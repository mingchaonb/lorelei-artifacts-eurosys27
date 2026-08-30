# zlib 1.3.2 压缩 workload

[English](README.md)

该 workload 使用上游 `minizip -9` 将同一份确定性 64 MiB 输入归档 5 次。AE 机器上的 native 五次运行中位数约为 1.77 秒。port 将 `minizip`、`miniunzip` 和它们的辅助 DSO 安装到 `tools/zlib/upstream-tests`，因此 workload 只运行安装后的 artifact。计时结束后，Python ZIP reader 解压每个 member 并校验 SHA-256。

x86-64 包使用 GNU cross compiler，因为 Blink AArch64 JIT 无法完成由 devkit Clang 构建的 zlib 1.3.2 workload。native 包同样使用 GCC，所有 Blink 测量保留 JIT 模式。

```bash
./evaluations/2-cli-benchmarks/zlib/run.sh
./evaluations/2-cli-benchmarks/zlib/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/zlib/run.sh --lanes native,qemu,blink,qemu-hecate
```
