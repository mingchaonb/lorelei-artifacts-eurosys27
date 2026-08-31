# zlib 1.3.2 验证（仅 TLC）

[English](README.md)

本配方通过固定 vcpkg overlay 安装 zlib 1.3.2 和上游 runtime 测试，生成 TLC thunk，再在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/zlib/run.sh
./evaluations/1-libs/zlib/run.sh --install-only
```

port 将 `zlib_example`、`zlib_example64` 与 `minigzip` 安装到 `tools/zlib/upstream-tests`，3 项 runtime case 在两条 lane 均通过。当前上游 CMake 共发现 14 项测试，其余 12 项是会调用 CMake 构建新程序的 install 与 package-consumer build-system 检查，installed-only runner 明确排除。不从源码树重建，也不运行纯 QEMU lane。
