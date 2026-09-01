# Evaluation 指南

[English](README.md)

`evaluations/` 是 Artifact Evaluation 的公开入口。这里按论文声明组织复现配方，不保存开发计划或迁移过程。

## 1. 评测分组

1. [库正确性验证](1-libs/README.zh-CN.md)
   - 验证 79 个 library package 的公开 C ABI 与边界机制。
   - 对比 native AArch64 和 Hecate x86-64。
   - 不运行纯 QEMU full-emulation lane。
2. [命令行性能复现](2-cli-benchmarks/README.zh-CN.md)
   - 复现论文中的 8 个命令行 workload。
   - 对比 native、4 个纯模拟器和 4 个 Hecate 集成路径。
3. [机制开销拆分](3-breakdown/README.zh-CN.md)
   - 测量单次调用、callback 地址来源识别和 Hecate 模拟器集成。
4. [游戏评测](4-games/README.zh-CN.md)
   - 比较 native、QEMU-Hecate、Box64 和 Box64-Hecate 游戏路径。
   - 在 host 侧记录 FPS 与 frametime。
5. [QEMU 修改量统计](5-modifications/README.zh-CN.md)
   - 统计 Lat、Risotto 与 Hecate 的 QEMU 接入修改量。
   - 为 Lat 使用可审计的 Box64/KZT build dependency closure。

各组 README 负责说明本组的声明、运行命令、参数、结果格式和排除项。单项配方 README 只说明对应 library、workload、breakdown 或游戏。

## 2. 准备环境

从仓库根目录依次运行：

```bash
./evaluations/install-devkit.sh
./evaluations/install-tools.sh
./evaluations/install-libs.sh
./evaluations/install-games.sh
```

安装脚本的职责为：

1. `install-devkit.sh`
   - 下载与 host 架构匹配的 Lorelei AE devkit。
   - 校验 SHA-256 后安装到 `.work/devkit/`。
2. `install-tools.sh`
   - 安装 native FFmpeg 输入准备工具。
   - 安装固定版本的 QEMU、Blink、Box64 和 FEX。
   - 安装函数调用 breakdown 专用的插桩 QEMU 和 callback breakdown 专用的插桩 Box64。
3. `install-libs.sh`
   - 依次调用 library 配方的 `run.sh --install-only`。
   - 失败后继续准备后续 library。
4. `install-games.sh`
   - 安装可再分发游戏的 native AArch64 与 guest x86-64 package。
   - 失败后继续准备后续游戏。

安装过程遵循以下规则：

- 不在每次运行前删除已经安装的 package。
- 所有 port 共享 `vcpkg/downloads/` 源码缓存。
- vcpkg 复用已经成功的 download、build 和 binary package 状态。
- 终端保留完整 vcpkg 输出，并在底部显示进度。
- 重定向输出或不需要终端控制序列时可传入 `--plain`。

## 3. 公共工具

`install-tools.sh` 使用以下默认路径：

| 工具 | 默认路径 | 用途 |
|---|---|---|
| Lorelei devkit | `.work/devkit/` | TLC、HLR、runtime、cross compiler 和 patched QEMU plugin |
| FFmpeg | `vcpkg/installed/arm64-linux/tools/ffmpeg/ffmpeg` | 准备媒体输入，不参与计时 |
| QEMU | `vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64` | 纯模拟与 Hecate 性能路径 |
| 插桩 QEMU | `vcpkg/installed/arm64-linux/tools/qemu-breakdown-ae/qemu-x86_64` | 只用于直通函数调用的阶段拆分 |
| Blink | `vcpkg/installed/arm64-linux/tools/blink-ae/blink` | 纯模拟与 Hecate 性能路径 |
| Box64 | `vcpkg/installed/arm64-linux/tools/box64-ae/box64` | 不带插桩的性能路径 |
| FEX | `vcpkg/installed/arm64-linux/tools/fex-ae/FEX` | 纯模拟与 Hecate 性能路径 |
| 插桩 Box64 | `vcpkg/installed/arm64-linux/tools/box64-callback-track-ae/box64-callback-track` | 只用于 callback 地址来源 breakdown |

普通 QEMU、Box64 与各自的插桩版本是独立 package。插桩版本不会替换普通 `QEMU` 或 `BOX64`，也不参与任何性能 lane。

## 4. 公共接口

所有公开脚本根据自身路径解析仓库根目录，可以从任意当前目录启动。

常用环境变量为：

| 变量 | 含义 |
|---|---|
| `LORELEI_DEVKIT` | 覆盖默认 `.work/devkit` |
| `QEMU` | 覆盖普通 QEMU 可执行文件路径 |
| `QEMU_BREAKDOWN` | 覆盖函数调用 breakdown 使用的插桩 QEMU 路径，不影响 `QEMU` 或性能评测 |
| `BLINK` | 覆盖 Blink 可执行文件路径 |
| `BOX64` | 覆盖不带插桩的普通 Box64 路径 |
| `FEX` | 覆盖 FEX 可执行文件路径 |
| `BOX64_CALLBACK_TRACK` | 覆盖 callback breakdown 使用的插桩 Box64 路径，不影响 `BOX64` 或性能评测 |
| `GAME_DIR` | 覆盖当前所选游戏的安装目录 |
| `REPETITIONS` | 覆盖性能 workload 的重复次数 |
| `TIMEOUT_SECONDS` | 降低单次 workload 的超时时间，不能调高 Figure 17 的 100 秒 hard limit |

批处理脚本具有以下共同特性：

- 单项失败不会阻止后续项目。
- 中断后重复相同命令会跳过成功项。
- 失败、中断和未完成项会被重新尝试。
- `--restart` 归档旧控制器状态并重新开始。
- `--plain` 关闭固定在终端底部的进度显示。

## 5. 目录与证据

```text
evaluations/
├── common/                         跨组共享代码与工具
├── 1-libs/<package>/              单个 library 配方
├── 2-cli-benchmarks/<workload>/   单个性能 workload
├── 3-breakdown/<experiment>/      单个机制实验
├── 4-games/<game>/                单个游戏配方
└── 5-modifications/               QEMU 修改量源码分析

vcpkg-overlay/
├── ports/<package>/               被测软件的源码、patch 与构建策略
├── ports-tools/<tool>/            公共工具配方
└── triplets/                      native、guest 与 Hecate 构建配置

.work/evaluations/                 可复用的 build、package 与 install 状态
```

结果目录的职责为：

- `results/<run-id>/` 保存评审者本地生成的证据。
- 每次运行使用新的 UTC 时间戳目录，不覆盖以前结果。
- `.work/`、vcpkg buildtree、安装 prefix、download cache 和临时输入不属于证据。
- 清理结果时不删除共享 vcpkg download 或 package cache。

所有评测至少记录：

1. 完整命令和退出状态。
2. 工具、源码与 patch 身份。
3. 运行环境与输入身份。
4. 原始输出。
5. 从原始数据得到结论的机器可读汇总。

不同评测组需要保存的附加证据由各组 README 规定。

## 6. 导出论文 CSV

最终导出只读取已经生成的原始证据，不会隐式运行 benchmark 或 TLC 覆盖率审计。完成各组 runner 后，还需要显式生成 coverage 与修改量证据，再运行统一导出器：

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
./evaluations/5-modifications/run.sh
python3 evaluations/export-paper-data.py
```

导出器在 `evaluations/paper-data/` 中写入 `overall.csv`、`game-fps.csv`、`function-breakdown.csv`、`callback-track.csv`、`coverage-effort.csv`、`modifications.csv` 和输入哈希 manifest。

<!--
## 7. SPARK GitHub Actions

作者维护用的 self-hosted workflow 不属于 evaluator 复现入口。
-->
