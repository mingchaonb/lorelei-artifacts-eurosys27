# GNU Libidn 1.43 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 获取官方 GNU Libidn 1.43 release，为 AArch64 与 x86-64 构建共享库和全部配置测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同 suite。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/libidn/run.sh
./evaluations/1-libs/libidn/run.sh --reference --verbose
./evaluations/1-libs/libidn/run.sh --install-only
```

port 将全部 17 项上游 API 测试安装到 `tools/libidn/upstream-tests`。`run.sh` 对称运行这些安装测试，不从源码树重建。文档、NLS 和语言 binding 仍然排除。
