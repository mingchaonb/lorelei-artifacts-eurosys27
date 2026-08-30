# json-c 0.19-20260627 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`，可用 `LORELEI_DEVKIT` 覆盖。本配方通过固定版本的 vcpkg overlay 获取官方 json-c 0.19-20260627 release，为 AArch64 与 x86-64 构建共享库和当前配置的全部上游测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同测试集。不创建 HLR feature，不运行 LoreHLR，不加载 HLR extension，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/json-c/run.sh
./evaluations/1-libs/json-c/run.sh --reference --verbose
./evaluations/1-libs/json-c/run.sh --install-only
```

当前配置关闭 thread-local serialization。port 将上游 CTest 注册的全部 28 项测试安装到 `tools/json-c/upstream-tests`。`run.sh` 只运行安装后的测试，不从源码树重建。release ELF version script 仍属于构建后的 DSO。
