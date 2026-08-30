# liblzma 5.8.3 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 安装 liblzma 5.8.3 和上游测试，生成 TLC thunk，再在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/liblzma/run.sh
./evaluations/1-libs/liblzma/run.sh --reference --verbose
./evaluations/1-libs/liblzma/run.sh --install-only
```

port 将官方 XZ 5.8.3 CMake 配置注册的全部 19 项测试安装到 `tools/liblzma/upstream-tests`，19 项在两条 lane 均通过。Hecate 为跨 thunk boundary 转移 ownership 的 filter option buffer 加载共享 allocator libc shim。`test_index` 内 24 个 case 在两条 lane 均按进程隔离，因为把全部 opaque index state 保留在同一组合进程会触发 Hecate 内部 fault，而每个独立上游 case 都能通过。不从源码树重建，也不运行纯 QEMU lane。
