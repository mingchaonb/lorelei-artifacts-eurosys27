# 命令行性能复现

[English](README.md)

本组用于复现论文命令行 workload 的执行时间。计时程序和共享库来自对应的 `evaluations/1-libs` 安装。`vcpkg/installed/arm64-linux` 下的官方 native FFmpeg 只负责准备媒体输入，不参与计时。

## 1. 当前 workload

当前仓库已接入论文使用的全部 8 个 workload：

| 序号 | Workload | 输入 | 计时操作 | 配方 |
|---:|---|---|---|---|
| 1 | FFTW 3.3.10 | `1024x1024` complex 2D problem | planning 与 forward transform | `fftw/` |
| 2 | zstd 1.5.7 | 确定性 64 MiB 数据 | level 3、单 worker 压缩 | `zstd/` |
| 3 | zlib 1.3.2 | 确定性 64 MiB 数据 | `minizip -9` | `zlib/` |
| 4 | OpenSSL 3.0.22 | 固定 1 MiB 内部 buffer | `openssl speed` EVP SHA-256 throughput | `openssl/` |
| 5 | FFmpeg 加 libmp3lame | 固定 WAV 片段 | MP3 编码 | `ffmpeg-mp3lame/` |
| 6 | FFmpeg 加 libfdk_aac | 固定 WAV 片段 | AAC 编码 | `ffmpeg-fdk-aac/` |
| 7 | FFmpeg 加 libvorbis | 固定 WAV 片段 | Vorbis 编码 | `ffmpeg-vorbis/` |
| 8 | FFmpeg 加 libx264 | 固定 Y4M 视频片段 | H.264 编码 | `ffmpeg-x264/` |

## 2. 对比路径

每个已接入 workload 默认运行 9 条路径：

1. `native`
   - native AArch64 程序和共享库。
2. `qemu`
   - x86-64 程序通过纯 QEMU 模拟运行。
3. `blink`
   - x86-64 程序通过纯 Blink 模拟运行。
4. `box64`
   - x86-64 程序通过纯 Box64 模拟运行。
5. `fex`
   - x86-64 程序通过纯 FEX 模拟运行。
6. `qemu-hecate`
   - QEMU 集成 Hecate，调用 native AArch64 共享库。
7. `blink-hecate`
   - Blink 集成 Hecate，调用 native AArch64 共享库。
8. `box64-hecate`
   - Box64 集成 Hecate，调用 native AArch64 共享库。
9. `fex-hecate`
   - FEX 集成 Hecate，调用 native AArch64 共享库。

版本一致性规则为：

- native 与 x86-64 程序来自同一个 `1-libs` 配方和上游版本。
- Hecate 与对应纯模拟路径运行相同 x86-64 CLI。
- Hecate host 库来自同一配方的 AArch64 安装。
- 输入在所有路径之间完全相同。
- 插桩 `box64-callback-track-ae` 不参与性能评测。

## 3. 准备输入

一次性准备全部确定性与媒体输入：

```bash
./evaluations/2-cli-benchmarks/_common/prepare-inputs.sh
```

输入分为：

1. 确定性数据
   - 由 Python 生成。
   - 供 zlib 与 zstd 使用。
2. 媒体数据
   - 来源由 [`_inputs/media-source.json`](_inputs/media-source.json) 固定。
   - 使用 `yt-dlp` 下载公开视频。
   - 使用 native FFmpeg 在计时区间外提取 WAV 与 Y4M 片段。

准备完成后，`_inputs/manifest.json` 记录：

- 每个输入的文件名。
- 字节大小。
- SHA-256。
- 来源与派生关系。

下载文件和派生二进制输入由 Git 忽略。Ubuntu 自带 `yt-dlp` 无法读取当前 YouTube metadata 时，可设置：

```bash
YT_DLP=/absolute/path/to/yt-dlp \
  ./evaluations/2-cli-benchmarks/_common/prepare-inputs.sh
```

## 4. 安装 workload

只安装公共工具和全部 workload 依赖，不运行计时：

```bash
./evaluations/2-cli-benchmarks/run-all.sh --install-only
```

该命令会：

1. 调用 `evaluations/install-tools.sh`。
2. 为全部 8 个 workload 调用对应的 `run.sh --install-only`。
3. 复用 `1-libs` 已安装的 native、guest、Hecate 和 thunk 状态。

`--install-only` 不下载媒体或生成 workload 输入。需要运行计时时，runner 会在缺少输入时调用第 3 节的准备脚本。

## 5. 运行全部 workload

运行全部 8 个 workload：

```bash
./evaluations/2-cli-benchmarks/run-all.sh
```

默认参数为：

- 每条路径重复 5 次。
- 单次运行 hard timeout 为 180 秒。
- workload 大小要求纯 QEMU 与纯 Blink 单次均低于 180 秒。
- runner 保存每次原始 wall-clock 时间，不只保存汇总。

OpenSSL 是指标例外。`openssl speed` 固定运行 3 秒，其主指标是命令输出的 SHA-256 throughput。该配方另外生成逐轮 throughput、各 lane 中位数和 Hecate 加速比，外层 wall-clock 时间只用于审计。

调整重复次数和 timeout：

```bash
REPETITIONS=7 TIMEOUT_SECONDS=240 \
  ./evaluations/2-cli-benchmarks/run-all.sh
```

## 6. 选择路径

只运行指定路径：

```bash
./evaluations/2-cli-benchmarks/run-all.sh \
  --lanes native,qemu,qemu-hecate
```

可选 lane 名称为：

- `native`
- `qemu`
- `blink`
- `box64`
- `fex`
- `qemu-hecate`
- `blink-hecate`
- `box64-hecate`
- `fex-hecate`

改变 lane、重复次数、timeout、devkit 或模拟器路径后，已有 batch state 不会与新配置混合。runner 会要求使用 `--restart` 创建新批次。

## 7. 批处理与恢复

控制器状态保存在：

```text
.work/evaluations/2-cli-benchmarks-batch/<mode>/
```

批处理行为为：

- workload 失败后继续运行后续项目。
- 重复相同命令会跳过成功项。
- 失败、中断和未完成项会重新尝试。
- `--restart` 将旧状态移到 `history/` 后重新开始。
- 新增或删除 workload 配方后，控制器拒绝沿用旧 plan，并要求使用 `--restart`。
- `--plain` 关闭固定在终端底部的进度显示。
- 交互终端显示最近完成的 3 项、当前 workload 和总进度。

生成作者参考结果：

```bash
./evaluations/2-cli-benchmarks/run-all.sh --reference
```

`--reference` 与 `--install-only` 不能同时使用。

## 8. 单项 workload

每个 `<workload>/run.sh` 是该项的公开入口。例如：

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
./evaluations/2-cli-benchmarks/zlib/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/zstd/run.sh \
  --lanes native,qemu,blink,qemu-hecate
```

单项 README 负责说明：

1. 输入格式与大小。
2. 完整 workload 参数。
3. 特殊模拟器选项。
4. 输出校验方法。
5. 当前已知限制。

## 9. 结果与证据

评审者结果写入：

```text
evaluations/2-cli-benchmarks/<workload>/results/<run-id>/
```

作者参考结果写入：

```text
evaluations/2-cli-benchmarks/<workload>/reference-results/<run-id>/
```

每个 workload 至少保存：

1. 每条 lane 的完整命令。
2. 每次重复的退出状态与 wall-clock 时间。
3. 输入文件大小与 SHA-256。
4. library package、CLI 和模拟器版本。
5. devkit 与 Hecate 组件身份。
6. timeout、重复次数和选择的 lane。
7. 从原始 sample 计算的中位数与范围。

删除评审者结果前先预览：

```bash
./evaluations/2-cli-benchmarks/delete-all-results.sh --dry-run
./evaluations/2-cli-benchmarks/delete-all-results.sh
```

参考结果使用独立清理脚本：

```bash
./evaluations/2-cli-benchmarks/delete-all-reference-results.sh --dry-run
./evaluations/2-cli-benchmarks/delete-all-reference-results.sh
```

清理脚本不会删除 `_inputs/`、共享 vcpkg download 或 package cache。
