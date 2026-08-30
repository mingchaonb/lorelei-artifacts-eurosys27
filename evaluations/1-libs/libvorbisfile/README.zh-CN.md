# libvorbisfile 1.3.7 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成 TLC thunk，并在 native 与 Hecate 运行相同定向 API workload。

```bash
./evaluations/1-libs/libvorbisfile/run.sh
./evaluations/1-libs/libvorbisfile/run.sh --reference --verbose
./evaluations/1-libs/libvorbisfile/run.sh --install-only
```

workload 通过 `ov_callbacks` table 向 `ov_test_callbacks` 传入确定性的非 Vorbis byte string，要求至少执行一次 guest read callback 后得到文档规定的负数 parse result。两条 lane 成功时均输出负数结果和正数 read count。`libvorbisfile.so.3` 保持独立 DSO，并依赖 `libvorbis` 与 `libogg`。callback table 由 TLC 处理，不使用 HLR。

libvorbis 1.3.7 CMake 配置没有注册专用 libvorbisfile 上游测试。port 仍将配置测试树安装到 `tools/libvorbisfile/upstream-tests`，定向 callback workload 在两条 lane 通过后，`run.sh` 对称记录 0/0。不运行纯 QEMU lane。
