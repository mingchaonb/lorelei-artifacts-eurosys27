# libdeflate 1.26 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 安装 libdeflate 1.26 和上游测试，生成 TLC thunk，并在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/libdeflate/run.sh
./evaluations/1-libs/libdeflate/run.sh --reference --verbose
./evaluations/1-libs/libdeflate/run.sh --install-only
```

port 将上游 CMake 注册的全部 8 个程序安装到 `tools/libdeflate/upstream-tests`，覆盖 checksum、allocation callback、incomplete code、invalid stream、literal-run-length overflow、overread protection、slow decompression 和 trailing byte。8 项测试在 native 与 Hecate 均通过。不从源码树重建，也不运行纯 QEMU lane。
