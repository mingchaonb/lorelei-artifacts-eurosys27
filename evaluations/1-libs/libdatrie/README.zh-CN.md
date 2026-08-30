# libdatrie 0.2.14 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 获取官方 libdatrie 0.2.14 release，为 AArch64 与 x86-64 构建共享库和全部配置测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同 suite。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/libdatrie/run.sh
./evaluations/1-libs/libdatrie/run.sh --reference --verbose
./evaluations/1-libs/libdatrie/run.sh --install-only
```

port 将全部 10 个上游测试程序安装到 `tools/libdatrie/upstream-tests`。`run.sh` 对称运行这些安装程序，不从源码树重建。`trietool` CLI 不是上游测试。port 名保持稳定以供 libthai 依赖。
