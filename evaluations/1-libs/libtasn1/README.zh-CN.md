# libtasn1 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 libtasn1 4.21.0，运行所选上游配置发现的全部 40 项测试。production target 为 `libtasn1.so.6`，两个架构从相同官方源码构建共享库。Hecate 使用 TLC GTL 与 HTL，不启用 HLR。`FILE` ownership 使用共享 libc shim，但机制仍分类为仅 TLC。

port 把完整 suite 安装到 `tools/libtasn1/upstream-tests`，包括 9 个 fuzz regression 程序、24 个普通程序、7 个 shell 测试、fixture 和 shell 测试使用的 3 个 CLI。`run.sh` 只使用安装文件，不重建源码。清理前验证中，40 项测试在两条 lane 均通过且分类相同，没有排除项。

```bash
./run.sh
```
