# libvorbis 1.3.7 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成 TLC thunk，并在 native 与 Hecate 运行相同定向 API workload。

```bash
./evaluations/1-libs/libvorbis/run.sh
./evaluations/1-libs/libvorbis/run.sh --reference --verbose
./evaluations/1-libs/libvorbis/run.sh --install-only
```

workload 创建 stereo Vorbis encoder，添加 comment，初始化 analysis state，提交 16 个 silent frame，查询一个 analysis block 并清理全部 state。两条 lane 均须报告 2 channels 与 44100 Hz。配方分别为 `libogg.so.0`、`libvorbis.so.0` 和 `libvorbisenc.so.2` 构建 TLC thunk，保留 DSO boundary。

vcpkg fetch 应用 CMake patch，将上游 encode/decode roundtrip suite 注册并安装到 `tools/libvorbis/upstream-tests`。定向 workload 后两条 lane 均通过该程序及内部全部 528 项检查。高层 `libvorbisfile` DSO 由独立 port 评测。不运行纯 QEMU lane。
