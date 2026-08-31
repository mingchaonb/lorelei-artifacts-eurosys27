# xxhash 0.8.3 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 安装 xxhash 0.8.3 和上游测试，生成 TLC thunk，再在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/xxhash/run.sh
./evaluations/1-libs/xxhash/run.sh --install-only
```

源码 patch 让完整官方 `tests/sanity_test.c` vector set 链接共享库并安装到 `tools/xxhash/upstream-tests`。上游通常在该测试内嵌 `XXH_IMPLEMENTATION`，patch 移除该 define，同时保留测试逻辑、CLI helper 与 vector。安装测试在两条 lane 均完成 49,948 项检查且输出相同。不从源码树重建，也不运行纯 QEMU lane。
