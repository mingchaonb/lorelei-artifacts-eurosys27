# lz4 1.10.0 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 安装 lz4 1.10.0 与上游测试，生成 TLC thunk，再在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/lz4/run.sh
./evaluations/1-libs/lz4/run.sh --install-only
```

源码 patch 增加上游 `tests/fuzzer.c` target，使其链接共享库并安装到 `tools/lz4/upstream-tests`。CTest 注册使用 seed 12345 运行 150 个确定性 cycle。安装测试在两条 lane 均通过，覆盖 normal、HC、dictionary、streaming 与 frame API。不从源码树重建，也不运行纯 QEMU lane。
