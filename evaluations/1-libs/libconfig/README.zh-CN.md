# libconfig 1.8.2 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定版本的 vcpkg overlay 获取官方 libconfig 1.8.2 release，为 AArch64 与 x86-64 构建共享库和当前配置的全部上游测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同测试集。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/libconfig/run.sh
./evaluations/1-libs/libconfig/run.sh --install-only
```

本配方只声明 C API。vcpkg port 将上游 C 测试程序和数据安装到 `tools/libconfig/upstream-tests`。`run.sh` 在对称的 native 与 Hecate lane 运行全部 16 项 C 测试，不从源码树重建。低优先级 C++ API 与 examples 仍然排除。
