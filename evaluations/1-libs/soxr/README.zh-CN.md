# libsoxr 0.1.3 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为两个架构共享库，生成 TLC thunk，并在 native 与 Hecate 运行相同定向 API workload。不使用 HLR。

```bash
./evaluations/1-libs/soxr/run.sh
./evaluations/1-libs/soxr/run.sh --reference --verbose
./evaluations/1-libs/soxr/run.sh --install-only
```

workload 执行 scalar one-shot mono conversion，将 8 个 sample 转为 16 个，并验证返回 frame 数与有限输出。两条 lane 均须报告 `ok` 和超过 8 个 output frame，不使用 callback 或 shim。

port 将完整配置 CTest tree 安装到 `tools/soxr/upstream-tests`。定向 workload 后两条 lane 均通过全部 vector 与 example-backed 测试，共 9/9。SIMD、OpenMP、libsamplerate binding 和 libavutil integration 已关闭。不运行纯 QEMU lane。
