# libcerf 3.5 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定的官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成 workload 范围内的 TLC thunk，并通过 native 与 Hecate 运行相同定向 public-API workload。port 没有 `hlr` feature，runner 不加载 HLR extension。

```bash
./evaluations/1-libs/libcerf/run.sh
./evaluations/1-libs/libcerf/run.sh --reference --verbose
./evaluations/1-libs/libcerf/run.sh --install-only
```

workload 通过 C ABI 计算 complex error function、Dawson function 与 Voigt profile，并检查结果有限且满足基本数值范围。两条 lane 成功时输出相同的九位数值。Clang patch 只为 complex infinity 与 NaN 常量启用上游已有的 `__builtin_complex` 构造路径。

port 将完整配置的 CTest tree 安装到 `tools/libcerf/upstream-tests`。定向 workload 后运行全部 9 项上游 C 数值测试，两条 lane 均通过 9/9。C++ interface、examples 和 manuals 在本配置中是被关闭的 build product，而非测试。不运行纯 QEMU lane。
