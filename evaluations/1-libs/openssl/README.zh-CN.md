# OpenSSL 验证（仅 TLC）

[English](README.md)

本配方固定 OpenSSL 3.0.22，production target 为 `libcrypto.so.3` 与 `libssl.so.3`。native AArch64 与 x86-64 package 从相同官方源码构建为共享库。

OpenSSL 是本批迁移的明确例外。port 只构建和安装软件 payload，不构建或安装上游测试。runner 安装两个架构的 package 并记录共享库 audit。`--install-only` 为接口一致性保留，`--reference` 写入只追加证据，`--verbose` 显示 vcpkg 输出并保留原始日志。

不运行 OpenSSL 测试、speed benchmark、Hecate lane 或纯 QEMU lane，因此标题有意不含 `[ALL TESTS PASSED]`。

```bash
./run.sh --reference
```
