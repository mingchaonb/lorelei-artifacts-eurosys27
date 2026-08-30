# bzip2 1.0.8 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本配方通过固定版本的 vcpkg overlay 安装 bzip2 1.0.8 及其上游测试，生成 TLC thunk，再在 native 与 Hecate 两条 lane 运行安装后的测试。

## 命令

```bash
./evaluations/1-libs/bzip2/run.sh
./evaluations/1-libs/bzip2/run.sh --reference --verbose
./evaluations/1-libs/bzip2/run.sh --install-only
```

port 构建链接共享库的官方 CLI，并将它和上游样例文件安装到 `tools/bzip2/upstream-tests`。runner 在两条 lane 复现完整上游 `make test` workload，包括 3 项压缩检查和 3 项解压检查。6 项字节比较在 native 与 Hecate 均通过。不从源码树重新构建，也不运行纯 QEMU lane。
