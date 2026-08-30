# lzo 2.10 验证（仅 TLC）

[English](README.md)

本配方通过固定 vcpkg overlay 安装 lzo 2.10 与上游测试，生成 TLC thunk，再在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/lzo/run.sh
./evaluations/1-libs/lzo/run.sh --reference --verbose
./evaluations/1-libs/lzo/run.sh --install-only
```

port 将上游 CMake 注册的 5 项测试安装到 `tools/lzo/upstream-tests`。4 项共享库测试在两条 lane 均通过，包括 `-mall` 的 37-method tree sweep。`testmini` 内嵌 miniLZO，不测试共享 ABI，因此只作为 native build check，明确不在 Hecate 运行。不从源码树重建，也不运行纯 QEMU lane。
