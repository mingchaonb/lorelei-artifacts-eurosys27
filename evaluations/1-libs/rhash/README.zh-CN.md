# RHash 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 RHash 1.4.6，运行当前配置选择的完整上游共享库 selftest。production target 为 `librhash.so.1`，两个架构从同一官方源码构建共享库。Hecate 使用 TLC GTL 与 HTL，不启用 HLR。OpenSSL integration、gettext 与 CLI 排除。

port 构建 `test_shared` 并安装到 `tools/rhash/upstream-tests`。`run.sh` 直接在 native 与 Hecate 运行该程序，不重建测试。清理前验证中两条 lane 都通过并输出 `All sums are working properly!`，没有配置 failure 或 skip。共享配置还关闭 CLI 与静态库，不提供纯 QEMU lane。

```bash
./run.sh --reference
```
