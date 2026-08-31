# libpsl 0.21.5 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 获取官方 libpsl 0.21.5 release，为 AArch64 与 x86-64 构建共享库和全部配置测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同 suite。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/libpsl/run.sh
./evaluations/1-libs/libpsl/run.sh --install-only
```

build 使用内置 PSL 并关闭 runtime IDNA。port 将 5 项 API 测试和 3 个 fuzz regression 程序安装到 `tools/libpsl/upstream-tests`。`run.sh` 在两条 lane 运行全部 8 项安装测试，不从源码树重建。CLI 工具不是上游测试。
