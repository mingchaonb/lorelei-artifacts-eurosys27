# libsndfile 1.2.2 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成 workload 范围的 TLC thunk，并在 native 与 Hecate 运行相同 public-API workload。不使用 HLR。

```bash
./evaluations/1-libs/libsndfile/run.sh
./evaluations/1-libs/libsndfile/run.sh --reference --verbose
./evaluations/1-libs/libsndfile/run.sh --install-only
```

workload 通过 5 个 virtual-I/O callback 向内存 WAV 写入 8 个 PCM16 sample，再打开相同 buffer、读回并逐字节比较。两条 lane 均须报告 8 个 sample 和正数 read、write callback 次数。persistent virtual-I/O callback table 由 TLC 处理，不使用 HLR 或 allocator shim。

port patch 支持共享库测试，并将完整配置 CTest tree 安装到 `tools/libsndfile/upstream-tests`。定向 workload 后两条 lane 均通过 142/142。只依赖 private symbol 的 `test_main` 不会在共享 build 注册。外部 FLAC、Ogg、Opus、Vorbis 与 MPEG codec 已关闭。不运行纯 QEMU lane。
