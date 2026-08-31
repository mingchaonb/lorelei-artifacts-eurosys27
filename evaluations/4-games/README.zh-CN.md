# 游戏评测

[English](README.md)

本组比较 native、QEMU-Hecate、Box64 和 Box64-Hecate 四条 ARM64 游戏路径，并使用 MangoHud 收集 FPS 与 frametime。库级正确性由 `evaluations/1-libs` 单独验证，本组只负责游戏运行与性能证据。

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

在评测容器内从仓库根目录运行：

```bash
./evaluations/install-games.sh
```

该脚本为前 5 个游戏安装：

- native AArch64 package。
- guest x86-64 package。
- 游戏数据与运行所需的固定目录布局。

没有单独的 Hecate 游戏 package。Hecate 运行 guest package 中未经修改的 x86-64 游戏程序，并使用 `1-libs` 安装的 AArch64 library、GTL、HTL 和 HLR 结果。重复安装会复用现有 vcpkg download、build 与 package 状态。

容器只负责下载、编译和安装。仓库以读写方式挂载，所有安装树都保存在 `.work/` 中并在宿主机可见。游戏 runner 不会在宿主机执行 vcpkg，也不会重新生成 HLR 或 thunk。

## 3. 运行游戏

退出评测容器，在 Ubuntu 24.04 ARM64 GUI 宿主机的桌面终端中运行游戏。每个 runner 使用 `--lane` 选择一条路径，并接受一个可选的位置参数作为 watchdog 秒数。默认路径是 `qemu-hecate`，默认 watchdog 为 30 秒：

```bash
./evaluations/4-games/supertux/run.sh --lane native 60
./evaluations/4-games/supertux/run.sh --lane qemu-hecate 60
./evaluations/4-games/supertux/run.sh --lane box64 60
./evaluations/4-games/supertux/run.sh --lane box64-hecate 60
```

四条路径分别使用容器安装的 ARM64 package、x86-64 package、QEMU、Box64 和 Hecate thunk。Hollow Knight 不提供可分发的 ARM64 package，因此没有 native lane。也可用 `GAME_LANE` 设置默认路径。

采集论文 FPS 数据时：

1. 对每条可用 lane 使用相同分辨率和游戏场景。
2. 根据进入目标游戏场景所需的时间，选择足够长的 watchdog。
3. 启动 runner，并手动进入目标场景。
4. 场景就绪后，保持游戏继续运行至少 15 秒。
5. 正常关闭游戏。论文导出取最后一个 sample 前第 12 秒到第 2 秒之间的 10 秒窗口。最后 2 秒不计入，避免关闭游戏的操作影响结果。

设置 `GAME_DIR` 可让任何 runner 使用用户指定的游戏目录，而不是 `.work/` 中已安装的 guest package：

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

渲染后端选择：

- runner 默认使用 OpenGL。
- 设置 `HOLLOW_USE_VULKAN=1` 时改用 Vulkan。

## 5. 启动前验证

共享 runner 始终运行宿主 OpenGL preflight。QEMU-Hecate 与 Box64-Hecate 还会使用选定 devkit 构建并执行 x86-64 thunk probe。probe 失败时，runner 在终端显示错误摘要和日志路径。

所有游戏验证：

- 宿主 `glxinfo -B` 能识别 renderer。软件 renderer 会产生警告并继续功能验证，但该次 FPS 不作为性能证据。
- XRandR display path。
- GL proc-address dispatch。
- Vulkan proc-address dispatch。
- 有序 thunk database 列表。

OpenArena 额外运行 SDL 1.2 video probe。其他游戏运行 SDL2 display probe。build 输出、probe stdout、stderr 与退出状态全部写入本次结果。

## 6. GUI 宿主机

游戏不在容器中运行。宿主机需要：

- Ubuntu 24.04 ARM64 GUI 会话。
- 与物理 GPU 匹配并已启用的 OpenGL 和 Vulkan 驱动。
- `mangohud`、`mesa-utils` 和 `vulkan-tools`。
- `libgl-dev`、`libglx-dev` 和 `libvulkan-dev`，用于编译 GL 与 Vulkan preflight probe。
- `x11-utils`、`x11-xserver-utils` 和 `xdotool`。
- `cmake`、`libdw1` 和 `libglib2.0-0`。

可使用以下命令安装通用工具。GPU 驱动仍按宿主机硬件单独安装：

```bash
sudo apt update
sudo apt install -y \
  mangohud mesa-utils vulkan-tools \
  libgl-dev libglx-dev libvulkan-dev \
  x11-utils x11-xserver-utils xdotool \
  cmake libdw1 libglib2.0-0
```

运行前用 `glxinfo -B` 和 `vulkaninfo --summary` 确认物理 GPU 可用。`llvmpipe`、`softpipe` 或其他软件 renderer 不能作为游戏性能结果。

runner 默认继承当前 GUI 会话的 `DISPLAY` 与 `XAUTHORITY`。从桌面终端启动时通常无需设置。需要覆盖当前图形会话时，可通过 `GUI_ENV` 指定一个同时包含这两个变量的文件：

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

MangoHud 默认包裹所选 lane 的 host 侧进程，因为 AArch64 GL 与 Vulkan driver 在该进程内执行。默认行为为：

- HUD 不显示在屏幕上。
- 每 100 ms 记录一次 sample。
- 原始 MangoHud CSV 写入本次结果目录。
- `fps-summary.json` 汇总稳定 FPS 与 frametime。

论文数据导出脚本直接读取原始 CSV，不会照搬 MangoHud 的全程 summary。脚本优先根据 MangoHud 的 `elapsed` 时间戳为每个游戏截取 `[最后一个 sample - 12 秒, 最后一个 sample - 2 秒)`，统计 sample 数量以及 FPS 平均值、最小值、最大值和总体方差。默认每 100 ms 采样一次，因此窗口通常包含约 100 个 sample。旧日志没有 `elapsed` 字段时才按固定采样间隔回退。少于 12 秒的记录会明确标记为数据不足，不会擅自缩短窗口。

导出每个游戏、每条 lane 最新且包含 MangoHud 记录的运行：

```bash
python3 evaluations/export-paper-data.py
```

可读表格写入 `evaluations/paper-data/game-fps.csv`。

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
evaluations/4-games/<game>/results/<UTC timestamp>-<lane>/
```

证据包括：

1. 游戏、lane、executable 与 package 身份。
2. devkit、QEMU、Box64、library 和 thunk 身份。
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

清理脚本不会删除游戏 package、共享 vcpkg cache 或用户提供的 `GAME_DIR`。
