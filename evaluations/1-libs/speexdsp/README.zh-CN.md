# SpeexDSP 1.2.1 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方安装官方 SpeexDSP 1.2.1 共享库和 release 提供的全部 5 个测试程序，生成一个 TLC thunk，并分别对 native AArch64 DSO 与 Hecate 运行相同程序。不加载 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/speexdsp/run.sh
./evaluations/1-libs/speexdsp/run.sh --reference --verbose
./evaluations/1-libs/speexdsp/run.sh --install-only
```

上游没有注册 `make check`，而是在 `libspeexdsp/Makefile.am` 声明 5 个 `noinst_PROGRAMS`，overlay 将其全部安装到 `tools/speexdsp/upstream-tests/bin`：

1. `testdenoise` 处理 4 个确定性 8 kHz PCM frame。
2. `testecho` 处理确定性 microphone 与 reference PCM 文件。
3. `testjitter` 测试 packet insertion、retrieval、reset、tick 与 frozen-sender recovery。
4. `testresample` 通过 floating-point resampler 转换 4 个确定性 PCM frame。
5. `testresample2` 扫描 1 kHz 到 128 kHz 的 output rate。

5 个程序在两条 lane 都必须以状态 0 退出。denoise、echo、jitter 与 stream-fed resample 输出逐字节相同。`testresample2` 的 sine input 在进入共享 DSO 前由 native 或 guest libm 计算，因此只检查输出非零且大小相同。port 关闭 SSE 与 NEON，使两条 lane 使用相同 portable 实现。vcpkg 安装后不从源码树重建。
