# libspng 0.7.4 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 安装 libspng 0.7.4 及上游测试，生成 TLC thunk，并在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/libspng/run.sh
./evaluations/1-libs/libspng/run.sh --install-only
```

源码 patch 构建并安装 208 项上游注册所需的全部程序和数据到 `tools/libspng/upstream-tests`。compatibility adjustment 避免新版 libpng 在拒绝 hIST chunk 时继续充当该 metadata 的 oracle，同时保留其他 image 与 metadata 比较。包括 41 项 expected-failure case 在内的 208 项测试在两条 lane 均通过。传递 `FILE *` 的测试使用 TLC libc shim。不从源码树重建，也不运行纯 QEMU lane。
