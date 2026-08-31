# FFmpeg 7.1.5 验证（TLC + HLR）

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本配方通过一个仓库 overlay port 和三个架构角色 root 安装 FFmpeg 7.1.5：

1. `native` 包含 7 个上游 AArch64 共享库、`ffmpeg`、`ffprobe` 和当前配置的 FATE 树。
2. `guest` 包含 Hecate 使用的对应 x86-64 库、CLI 程序和 FATE 树。
3. `hecate` 包含 7 个经过 HLR 的 AArch64 host 库。

每个包都把当前配置的测试安装到 `tools/ffmpeg/upstream-tests`。

```bash
./evaluations/1-libs/ffmpeg/run.sh --verbose
```

评审者只会看到两条结果 lane：

1. Native AArch64 使用安装后的 native 库执行安装后的 native FATE 树。
2. Hecate 使用 7 个生成的 TLC thunk 和 7 个 HLR AArch64 库，执行安装后的 x86-64 FATE 树。

port 固定到上游 tag `n7.1.5` 和 commit `3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587`。安装时，它捕获 FFmpeg 实际的 C 编译命令，并对以下 DSO translation-unit closure 分别运行 HLR：

- `libavutil`
- `libswresample`
- `libswscale`
- `libavcodec`
- `libavformat`
- `libavfilter`
- `libavdevice`

生成的源码与 FileContext 文件留在 vcpkg 可丢弃 buildtree 中，不作为仓库输入。安装后的 package 保留 7 份源码列表以及 TLC、HLR 统计供审计。提交到仓库的 `Symbols.conf` 固定由 TLC 分析的已安装 CLI 与 FATE API surface，`Desc.h` 记录 callback ABI 描述。

TLC callback replacement 已关闭，因此保存的 callback 由 HLR 处理。HLR 后 patch 导出 `LoreGetFileContext`，并在 C static descriptor 中保留原始 host 函数指针，因为运行时 FDG expression 不是常量。它们不会全局关闭 FDG，动态赋值和调用仍保留生成的 FDG guard。

本配方采用原复现记录所述的无 samples、刻意收窄的 FFmpeg 配置。由于配置关闭 image2 demuxer，native 基线预计有 20 项 pixfmt FATE 失败，Hecate 对应失败分类为基线跳过。任何 Hecate 独有失败、测试未完整执行、manifest 不一致，或连续 5 次 `api-threadmessage` 检查中的失败都会使评测失败。

MP3、FDK AAC、Vorbis 和 x264 四个命令行 workload 属于性能证据，不在本目录作为额外上游单元测试计数。
