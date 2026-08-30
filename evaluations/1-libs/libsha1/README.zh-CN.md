# libsha1 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 libsha1 0.1.0，验证 6 个上游 CUnit case 使用的 API。production target 为 `libsha1.so`，native AArch64 与 x86-64 guest 包从相同官方源码构建为共享库。Hecate 使用 TLC 生成的 GTL 与 HTL，不启用 HLR，也不声明 workload 外 API。CUnit 只是测试依赖，不属于目标 ABI。

port 安装 CUnit，并构建、安装完整 6-case 上游测试。`run.sh` 只使用安装后的 package，运行 native 与 Hecate，绝不运行纯 QEMU lane。两条 lane 均以状态 0 退出且输出等价即为成功。`--install-only` 在构建与 audit 后停止，`--reference` 写入只追加证据。

```bash
./run.sh --reference
```
