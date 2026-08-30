# OpenSSL SHA-256 workload

[English](README.md)

本 workload 使用 OpenSSL 3.0.22 依次对 3 份相同的确定性 256 MiB 文件计算 SHA-256。它与其他 CLI workload 一样统计完整命令的 wall-clock execution time，而不是运行固定时长的 throughput benchmark。AE 机器上的 native 五次运行中位数约为 1.67 秒。

公开命令为：

```bash
openssl dgst -sha256 -binary -out OUTPUT data-256m.bin data-256m.bin data-256m.bin
```

native 与 x86-64 CLI、`libcrypto.so.3` 和 `libssl.so.3` 均来自 `evaluations/1-libs/openssl` 的固定配方。Hecate 路径使用同一 AArch64 安装生成的 TLC thunk。输入由 `_common/prepare-inputs.sh` 确定性生成并记录 SHA-256。

每次重复输出 3 个 32 字节 binary digest。runner 使用 Python 计算预期值，并要求所有已完成 lane 的每次输出完全一致。主结果来自公共测量器生成的 lane TSV 与 JSON，单位为秒。

当前固定版本的 Box64 会在启动 OpenSSL 3.0.22 guest binary 时触发 `SIGSEGV`，普通 Box64 与 Box64 + Hecate 两条路径因此记录为明确排除项。Blink 若超过 native 时间的 20 倍也按统一 Figure 17 口径排除。runner 会在结果 JSON 和导出的 CSV 中保留具体原因，不会把这些路径伪装成缺失或成功数据。

运行单项：

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh
```

只准备依赖：

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh --install-only
```
