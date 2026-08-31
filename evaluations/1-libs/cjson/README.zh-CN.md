# cJSON 1.7.19 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本配方通过固定版本的 vcpkg overlay 获取官方 cJSON 1.7.19 release，为 AArch64 与 x86-64 构建共享库和当前配置的全部上游测试，通过 vcpkg 安装测试，从安装后的程序生成 TLC thunk，再在 native 与 Hecate 两条 lane 运行相同测试集。它不创建 HLR feature，不运行 LoreHLR，不加载 HLR extension，也不运行纯 QEMU lane。

## 命令

```bash
./evaluations/1-libs/cjson/run.sh
./evaluations/1-libs/cjson/run.sh --install-only
```

## 上游测试范围

vcpkg port 将当前配置的全部 19 项上游 core 测试安装到 `tools/cjson/upstream-tests`。自包含 `run.sh` 只在对称的 native 与 Hecate lane 运行这些安装后的测试，不运行纯 QEMU lane，也不从上游源码树重建测试。可选 cJSON Utils DSO 仍然排除。
