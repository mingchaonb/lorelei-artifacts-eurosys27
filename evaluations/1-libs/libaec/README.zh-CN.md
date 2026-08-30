# libaec 1.1.7 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方把固定的官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成限于 workload 的 TLC thunk，并在 native 与 Hecate 路径运行相同 public-API workload。port 没有 `hlr` feature，runner 不加载 HLR extension。devkit 没有 QEMU 时可设置 `QEMU=/path/to/qemu-x86_64`。

```bash
./evaluations/1-libs/libaec/run.sh
./evaluations/1-libs/libaec/run.sh --reference --verbose
./evaluations/1-libs/libaec/run.sh --install-only
```

workload 对 32 个确定性 16-bit sample 预处理并压缩，再通过 `libaec.so.0` 解压，要求逐字节相同，同时生成独立的 `libsz.so.2` thunk。成功时两条 lane 均报告正数压缩大小、64 个解码字节和结果 0，不使用 callback 或 shim。

port 将完整的当前配置 CTest tree 安装到 `tools/libaec/upstream-tests`。定向 workload 后，`run.sh` 运行全部 option、buffer、seeking、random-access 与 sample-data 测试，两条 lane 均通过 7/7。不运行纯 QEMU lane。
