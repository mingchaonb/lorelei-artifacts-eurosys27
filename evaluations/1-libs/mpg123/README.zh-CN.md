# mpg123 1.33.7 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成 TLC thunk，并在 native 与 Hecate 运行相同 public-API workload。不使用 HLR。

```bash
./evaluations/1-libs/mpg123/run.sh
./evaluations/1-libs/mpg123/run.sh --reference --verbose
./evaluations/1-libs/mpg123/run.sh --install-only
```

workload 初始化 libmpg123，创建 generic decoder handle，读取 flag 参数，销毁 handle 并 shutdown。两条 lane 均须输出 `mpg123:0` 和相同 flag，不使用 audio device、输入文件、callback 或 shim。

port 将当前 Automake suite 选择的全部 6 项测试安装到 `tools/mpg123/upstream-tests`，两条 lane 均通过 6/6。player、network、CPU-specific decoder dispatch 与 device backend 已关闭。不运行纯 QEMU lane。
