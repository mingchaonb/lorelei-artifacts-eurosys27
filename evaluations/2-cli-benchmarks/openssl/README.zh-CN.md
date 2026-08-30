# OpenSSL SHA-256 workload

[English](README.md)

本 workload 运行 OpenSSL 3.0.22 自带的 `openssl speed`，测量 EVP SHA-256 对固定 1 MiB buffer 的吞吐。每次调用测量 3 秒，在提高稳定性的同时让纯 QEMU 与纯 Blink 的单次运行保持在 CLI 组的 180 秒限制内。

公开命令为：

```bash
openssl speed -mr -elapsed -seconds 3 -bytes 1048576 -evp sha256
```

native 与 x86-64 CLI、`libcrypto.so.3` 和 `libssl.so.3` 均来自 `evaluations/1-libs/openssl` 的固定配方。Hecate 路径使用同一 AArch64 安装生成的 TLC thunk。`-mr` 生成可机器解析的 `+F` throughput 记录，runner 要求每次重复都成功输出该记录。

本 workload 的主指标是 SHA-256 bytes per second，不是 `openssl speed` 进程的外层 wall time。`-seconds 3` 会让所有路径主动运行约 3 秒，因此外层 wall time 只用于审计。`throughput.tsv` 保存每轮吞吐，`throughput-summary.json` 保存各 lane 的中位数、范围、Hecate 相对纯模拟的加速比，以及 Hecate 相对 native 的比例。

运行单项：

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh
```

只准备依赖：

```bash
./evaluations/2-cli-benchmarks/openssl/run.sh --install-only
```
