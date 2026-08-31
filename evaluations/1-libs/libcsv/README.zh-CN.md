# libcsv 3.0.3 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定版本的 vcpkg overlay 获取官方 libcsv 3.0.3 release，为 AArch64 与 x86-64 构建共享库和全部配置的上游测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同测试集。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/libcsv/run.sh
./evaluations/1-libs/libcsv/run.sh --install-only
```

vcpkg port 将完整上游 `check_csv` 程序安装到 `tools/libcsv/upstream-tests`。自包含 `run.sh` 在对称 native 与 Hecate lane 运行该程序，不从源码树重建，也不运行纯 QEMU lane。
