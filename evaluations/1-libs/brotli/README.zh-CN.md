# brotli 1.2.0 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本配方通过固定版本的 vcpkg overlay 安装 brotli 1.2.0 及其上游测试，生成 TLC thunk，再在 native 与 Hecate 两条 lane 运行安装后的测试。

## 命令

```bash
./evaluations/1-libs/brotli/run.sh
./evaluations/1-libs/brotli/run.sh --install-only
```

port 将上游 CLI 和官方 release 测试数据安装到 `tools/brotli/upstream-tests`。runner 在两条 lane 运行全部 28 项上游 roundtrip 注册和 2 项 compatibility-vector 注册。30 项测试在 native 与 Hecate 均通过。共用 DSO 同时作为 encoder 和 decoder 的依赖接受测试。不从源码树重新构建，也不运行纯 QEMU lane。
