# libsamplerate 0.2.2 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成 workload 范围的 TLC thunk，并在 native 与 Hecate 运行相同定向 public-API workload。port 无 `hlr` feature，runner 不加载 HLR extension。

```bash
./evaluations/1-libs/libsamplerate/run.sh
./evaluations/1-libs/libsamplerate/run.sh --reference --verbose
./evaluations/1-libs/libsamplerate/run.sh --install-only
```

workload 创建由 callback 提供输入的 mono converter，通过持续存在的 guest callback 返回一个固定 8-frame input block，请求 2.0 ratio，并验证输出 frame 数与 callback 次数。两条 lane 成功时均报告正 frame 数、1 次 callback 和 error 0。callback replacement 由 TLC 完成，不使用 HLR 或 shim。

port 将包括 FFTW comparison 依赖的完整配置 CTest tree 安装到 `tools/libsamplerate/upstream-tests`。定向 workload 后，两条 lane 均通过全部 13/13。audio-device example 是关闭的 build product。不运行纯 QEMU lane。
