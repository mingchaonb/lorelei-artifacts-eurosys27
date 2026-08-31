# libexif 0.6.26 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 获取官方 libexif 0.6.26 release，为 AArch64 与 x86-64 构建共享库和全部配置测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同 suite。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/libexif/run.sh
./evaluations/1-libs/libexif/run.sh --install-only
```

port 将全部 15 项配置测试所需的程序、脚本和数据安装到 `tools/libexif/upstream-tests`。两条 lane 均有 14 项通过，可选 `libfailmalloc` 测试按上游规则跳过。不从源码树重建。文档、NLS 和 release 携带的 binary 仍然排除。
