# Opus 1.5.2 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为两个架构共享库，生成 TLC thunk，并在 native 与 Hecate 运行相同 API workload。不使用 HLR。

```bash
./evaluations/1-libs/opus/run.sh
./evaluations/1-libs/opus/run.sh --reference --verbose
./evaluations/1-libs/opus/run.sh --install-only
```

workload 创建 48 kHz mono encoder，通过 variadic CTL API 设置 64 kbit/s bitrate，编码一个 silent frame，再通过另一 CTL request 读取 bitrate 并销毁 encoder。两条 lane 均须报告正 packet size 和 bitrate 64000。`Desc.h` 提供 TLC 的 request-dependent variadic extractor，不使用 HLR 或 shim。

vcpkg fetch patch 保留兼容共享库的测试并安装到 `tools/opus/upstream-tests`。当前共享配置注册的 4 项测试在两条 lane 均通过 4/4。依赖 private symbol 的 extension target 无法链接 public DSO，因此不注册。不运行纯 QEMU lane。
