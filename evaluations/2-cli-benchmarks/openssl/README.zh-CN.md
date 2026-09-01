# OpenSSL SHA-256 workload

[English](README.md)

本 workload 使用 OpenSSL 3.0.22，对 3 份相同的确定性 256 MiB 文件拼接后的内容计算一次 SHA-256。它与其他 CLI workload 一样统计固定命令的 wall-clock execution time，而不是运行固定时长的 throughput benchmark。

port 将专用客户端安装到 `tools/openssl/upstream-tests/sha256-ae`。计时命令等价于：

```bash
sha256-ae OUTPUT data-256m.bin data-256m.bin data-256m.bin
```

port 也会安装原始 `openssl` 命令。QEMU-Hecate 能够执行它原有的 `dgst` 路径。对称对比使用专用客户端，是因为普通 Box64 没有 wrapper 住 monolithic 命令导入的大量无关 OpenSSL 3 management 接口。这是对比模拟器的 wrapper 覆盖限制，不是 Hecate 执行失败。

客户端调用 `libcrypto.so.3` 中的 `SHA256_Init`、`SHA256_Update` 和 `SHA256_Final`。文件输入和输出留在 guest libc 内，不会让 guest `FILE *` 穿过库边界。native 与 x86-64 客户端及两种架构的 `libcrypto.so.3` 均来自 `evaluations/1-libs/openssl` 的固定配方。Hecate 路径使用同一 AArch64 安装生成的 TLC thunk。输入由 `_common/prepare-inputs.sh` 确定性生成并记录 SHA-256。

每次重复输出一个 32 字节 binary digest。runner 使用 Python 独立计算预期值，并要求所有已完成 lane 的每次输出完全一致。主结果来自公共测量器生成的 lane TSV 与 JSON，单位为秒。

该 workload 运行公共定义中的全部九条 lane，包括普通 Box64 与 Box64 + Hecate。普通 Box64 对这三个 SHA-256 接口使用其内置 OpenSSL wrapper，不会强制用 x86-64 模拟执行 `libcrypto.so.3`。非 native lane 只有实际达到 native 中位时间 20 倍且不超过 100 秒的统一截止时间时，才从 Figure 17 排除。结果 JSON 和导出的 CSV 会保留实测 timeout，不会用缺失值或成功值替代。

运行单项：

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh
```

只准备依赖：

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh --install-only
```
