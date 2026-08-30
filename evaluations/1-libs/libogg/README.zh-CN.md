# libogg 1.3.6 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成 workload 范围的 TLC thunk，并在 native 与 Hecate 运行相同定向 public-API workload。port 无 `hlr` feature，runner 不加载 HLR extension。

```bash
./evaluations/1-libs/libogg/run.sh
./evaluations/1-libs/libogg/run.sh --reference --verbose
./evaluations/1-libs/libogg/run.sh --install-only
```

workload 使用固定 serial number 创建 stream，提交一个 7-byte 的 beginning-and-end packet，flush 一个 page，验证 header 与 body 大小并清理 stream。两条 lane 成功时均输出一个 body 为 7 byte 的 page。测试链接共享 ABI，不把 Ogg 实现源码编入程序。

port patch 使共享 build 保留两个上游 bitwise 与 framing selftest，并安装到 `tools/libogg/upstream-tests`。定向 workload 后两条 lane 均通过 2/2。不运行纯 QEMU lane。
