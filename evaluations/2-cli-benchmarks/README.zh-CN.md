# 命令行 workload 复现

[English](README.md)

本组评测复现论文使用的八个命令行 workload。所有计时程序和共享库都来自对应的 `evaluations/1-libs` 安装。`vcpkg/installed/arm64-linux` 下独立安装的官方 FFmpeg 只用于准备输入，绝不参与计时。

workload 包括：

1. FFTW
2. zstd 压缩
3. zlib 压缩
4. OpenSSL SHA-256
5. FFmpeg 加 libmp3lame
6. FFmpeg 加 libfdk_aac
7. FFmpeg 加 libvorbis
8. FFmpeg 加 libx264

每个配方至少记录五次重复、完整命令、退出状态、wall-clock 时间、输入大小与 SHA-256、包版本和模拟器 revision。单次计时的硬限制为 180 秒。workload 大小经过校准，使纯 QEMU 和纯 Blink 路径都低于该限制。

## 执行路径

对比使用完全一致的 native 和模拟软件版本：

- native AArch64
- 纯 QEMU x86-64 模拟
- 纯 Blink x86-64 模拟
- 纯 Box64 x86-64 模拟
- 纯 FEX x86-64 模拟
- QEMU 加 Hecate
- Blink 加 Hecate
- Box64 加 Hecate
- FEX 加 Hecate

Blink、Box64 和 FEX 的 Hecate 环境遵循 `evaluations/3-breakdown/hecate-emulators`。`LORELEI_DEVKIT` 默认为仓库内的 `.work/devkit`。模拟器默认使用 `evaluations/install-tools.sh` 安装的固定版本 vcpkg 工具，可用 `QEMU`、`BLINK`、`BOX64` 和 `FEX` 覆盖。

## 输入

一次性准备确定性输入和媒体输入：

```bash
./evaluations/2-cli-benchmarks/_common/prepare-inputs.sh
```

媒体来源是 [`_inputs/media-source.json`](_inputs/media-source.json) 标识的公开视频。下载文件和所有派生二进制输入均由 Git 忽略。准备命令会记录准确大小和 SHA-256。

系统 `yt-dlp` 必须足够新，能够读取当前 YouTube metadata。Ubuntu 的旧包可能失败，脚本会明确报告该情况，并支持 `YT_DLP=/absolute/path/to/yt-dlp`。

## 运行

顺序运行所有可用 workload：

```bash
./evaluations/2-cli-benchmarks/run-all.sh
```

批处理状态保存在 `.work/evaluations/2-cli-benchmarks-batch/`。重复执行会跳过成功项并重试失败或中断项。`--restart` 归档旧状态后重新开始。交互终端在底部显示最近三个结果、当前 workload 和总进度。`--plain` 使用普通日志输出。

同一 runner 还能生成作者参考证据、选择 lane 或只准备依赖：

```bash
./evaluations/2-cli-benchmarks/run-all.sh --reference
./evaluations/2-cli-benchmarks/run-all.sh --lanes native,qemu,qemu-hecate
./evaluations/2-cli-benchmarks/run-all.sh --install-only
```

本地输出写入各 workload 的 `results/`，参考输出写入 `reference-results/`，后者可以显式提交。

使用相应的受保护清理脚本删除评审者或作者结果目录。先传入 `--dry-run` 查看准确目标：

```bash
./evaluations/2-cli-benchmarks/delete-all-results.sh
./evaluations/2-cli-benchmarks/delete-all-reference-results.sh
```
