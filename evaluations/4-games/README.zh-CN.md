# 游戏评测

[English](README.md)

本组验证 Hecate 是否能通过真实 graphics、window system、SDL、GL 和 Vulkan 路径启动 x86-64 游戏，并使用 MangoHud 收集 FPS 与 frametime。库级正确性由 `evaluations/1-libs` 单独验证，本组只负责游戏运行与性能证据。

## 1. 当前游戏

| 游戏 | 版本 | 获取方式 | 默认 graphics 路径 | 入口 |
|---|---:|---|---|---|
| AssaultCube | 1.3.0.2 | artifact 可下载 | OpenGL | `assaultcube/run.sh` |
| OpenArena | 0.8.8 | artifact 可下载 | OpenGL 加 SDL 1.2 | `openarena/run.sh` |
| Red Eclipse | 2.0.0 | artifact 可下载 | OpenGL | `redeclipse/run.sh` |
| SuperTux | 0.6.3 | artifact 可下载或构建 | OpenGL | `supertux/run.sh` |
| SuperTuxKart | 1.4 | artifact 可下载 | OpenGL | `supertuxkart/run.sh` |
| Hollow Knight | 用户合法持有的副本 | artifact 不下载、不再分发 | OpenGL，可选 Vulkan | `hollow-knight/run.sh` |

[`sources.json`](sources.json) 固定 5 个可再分发游戏的上游版本、归档 URL、SHA-256 和 guest 可执行文件身份。Hollow Knight 是付费专有游戏，因此只提供 runner。

## 2. 安装可再分发游戏

从仓库根目录运行：

```bash
./evaluations/install-games.sh
```

该脚本为前 5 个游戏安装：

- native AArch64 package。
- guest x86-64 package。
- 游戏数据与运行所需的固定目录布局。

没有单独的 Hecate 游戏 package。Hecate 运行 guest package 中未经修改的 x86-64 游戏程序，并使用 `1-libs` 安装的 AArch64 library、GTL、HTL 和 HLR 结果。重复安装会复用现有 vcpkg download、build 与 package 状态。

## 3. 运行游戏

每个 runner 接受一个可选的位置参数，表示 watchdog 秒数。默认值为 30 秒：

```bash
./evaluations/4-games/assaultcube/run.sh
./evaluations/4-games/openarena/run.sh 30
./evaluations/4-games/redeclipse/run.sh 30
./evaluations/4-games/supertux/run.sh 30
./evaluations/4-games/supertuxkart/run.sh 60
```

采集论文 FPS 数据时：

1. 根据进入目标游戏场景所需的时间，选择足够长的 watchdog。
2. 启动 runner，并手动进入目标场景。
3. 场景就绪后，保持游戏继续运行至少 15 秒。
4. 正常关闭游戏。论文导出取最后一个 sample 前第 12 秒到第 2 秒之间的 10 秒窗口。最后 2 秒不计入，避免关闭游戏的操作影响结果。

设置 `GAME_DIR` 可让任何 runner 使用用户指定的游戏目录，并跳过该游戏的 vcpkg package 安装：

```bash
GAME_DIR=/absolute/path/to/game \
  ./evaluations/4-games/openarena/run.sh 30
```

`GAME_DIR` 必须直接对应 runner 预期的目录结构。找不到 guest executable 时，脚本会打印解析后的准确路径。

## 4. Hollow Knight

评审者需要提供自己的 Linux x86-64 副本。目录中必须直接包含：

- `Hollow Knight` 可执行文件。
- `Hollow Knight_Data/` 数据目录。

默认运行 OpenGL：

```bash
GAME_DIR="/absolute/path/to/Hollow Knight" \
  ./evaluations/4-games/hollow-knight/run.sh 45
```

选择 Vulkan：

```bash
GAME_DIR="/absolute/path/to/Hollow Knight" \
HOLLOW_USE_VULKAN=1 \
  ./evaluations/4-games/hollow-knight/run.sh 45
```

## 5. 启动前验证

共享 runner 会先使用选定 devkit 构建并执行 x86-64 probe。只有全部 preflight 通过后才启动游戏。

所有游戏验证：

- XRandR display path。
- GL proc-address dispatch。
- Vulkan proc-address dispatch。
- 有序 thunk database 列表。

OpenArena 额外运行 SDL 1.2 video probe。其他游戏运行 SDL2 display probe。build 输出、probe stdout、stderr 与退出状态全部写入本次结果。

## 6. 图形环境

runner 默认继承当前环境的 `DISPLAY` 与 `XAUTHORITY`。Docker 启动命令已经传入这两个变量，无需再创建环境文件。需要覆盖当前图形会话时，可通过 `GUI_ENV` 指定一个同时包含这两个变量的文件：

```bash
GUI_ENV=/absolute/path/to/gui-env.txt \
  ./evaluations/4-games/supertux/run.sh 30
```

每个游戏使用独立可写 home，默认位于：

```text
.work/evaluations/games/runtime-home/<game>/
```

可使用 `RUNTIME_HOME_ROOT` 覆盖根目录。

## 7. MangoHud 采集

MangoHud 默认包裹 host 侧 QEMU 进程，因为 AArch64 GL 与 Vulkan driver 在该进程内执行。默认行为为：

- HUD 不显示在屏幕上。
- 每 100 ms 记录一次 sample。
- 原始 MangoHud CSV 写入本次结果目录。
- `fps-summary.json` 汇总稳定 FPS 与 frametime。

论文数据导出脚本直接读取原始 CSV，不会照搬 MangoHud 的全程 summary。脚本优先根据 MangoHud 的 `elapsed` 时间戳为每个游戏截取 `[最后一个 sample - 12 秒, 最后一个 sample - 2 秒)`，统计 sample 数量以及 FPS 平均值、最小值、最大值和总体方差。默认每 100 ms 采样一次，因此窗口通常包含约 100 个 sample。旧日志没有 `elapsed` 字段时才按固定采样间隔回退。少于 12 秒的记录会明确标记为数据不足，不会擅自缩短窗口。

导出每个游戏最新且包含 MangoHud 记录的运行：

```bash
python3 evaluations/export-paper-data.py
```

可读表格写入 `evaluations/paper-data/game-fps.csv`。加 `--reference` 时，脚本读取 `reference-results/`，而不是 `results/`。

关闭采集：

```bash
MANGOHUD_ENABLED=0 ./evaluations/4-games/openarena/run.sh 30
```

追加 MangoHud 配置：

```bash
MANGOHUD_CONFIG_EXTRA=output_folder=/absolute/path \
  ./evaluations/4-games/openarena/run.sh 30
```

## 8. 结果与证据

每次运行写入：

```text
evaluations/4-games/<game>/results/<UTC timestamp>/
```

证据包括：

1. 游戏、guest executable 与 package 身份。
2. devkit、QEMU、library 和 thunk 身份。
3. preflight build 与运行日志。
4. 完整游戏启动命令和 watchdog 状态。
5. MangoHud 原始样本。
6. `fps-summary.json`。
7. `game-fps.csv` 保留的 result 与原始日志路径。

清理评审者结果前先预览：

```bash
./evaluations/4-games/delete-all-results.sh --dry-run
./evaluations/4-games/delete-all-results.sh
```

参考结果使用独立脚本：

```bash
./evaluations/4-games/delete-all-reference-results.sh --dry-run
./evaluations/4-games/delete-all-reference-results.sh
```

清理脚本不会删除游戏 package、共享 vcpkg cache 或用户提供的 `GAME_DIR`。
