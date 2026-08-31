# GNU libiconv 1.18 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 获取官方 GNU libiconv 1.18 release，为 AArch64 与 x86-64 构建共享库和全部配置测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同 suite。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/libiconv/run.sh
./evaluations/1-libs/libiconv/run.sh --install-only
```

port 将完整上游 `make check` driver、辅助程序、配置支持文件和数据安装到 `tools/libiconv/upstream-tests`。`run.sh` 对称运行该安装 suite，不配置或构建另一份上游源码树。

上游 `make check` 还需要一个仅 host 使用的 locale shim 支持 CLI substitution 测试。guest 选择 UTF-8 locale，而 native 库解析 GNU `char` encoding 时原本只能看到 host process 的 C locale。shim 只把 `nl_langinfo(CODESET)` 映射为 `UTF-8`，不会加载进 guest。
