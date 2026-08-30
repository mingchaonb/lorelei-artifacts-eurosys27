# libbase64 0.5.2 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定版本的 vcpkg overlay 安装 libbase64 0.5.2 和上游测试，生成 TLC thunk，再在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/libbase64/run.sh
./evaluations/1-libs/libbase64/run.sh --reference --verbose
./evaluations/1-libs/libbase64/run.sh --install-only
```

源码 patch 让两个上游测试程序链接共享库并安装到 `tools/libbase64/upstream-tests`。`test_base64` 覆盖 known answer、无效输入、byte table、streaming 和 roundtrip，上游 benchmark 也在两条 lane 完成。两个安装测试在 native 与 Hecate 均通过。不从源码树重建，也不运行纯 QEMU lane。
