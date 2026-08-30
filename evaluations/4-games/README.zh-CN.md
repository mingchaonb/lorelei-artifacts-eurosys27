# 游戏评测

[English](README.md)

本组包含用于复现游戏性能和可玩性的配方与证据。库级 GLVND 与 Vulkan 验证位于 `evaluations/1-libs`。

每个游戏采用与 library evaluation 相同的配方布局，并由自身的 `run.sh` 启动。`LORELEI_DEVKIT` 使用仓库统一默认值。可选的 `SECONDS` 参数设置 watchdog 时长。`GAME_DIR` 覆盖当前游戏的默认安装目录，同时跳过该游戏 vcpkg package 的安装。

```bash
./evaluations/4-games/openarena/run.sh 30
./evaluations/4-games/supertuxkart/run.sh 60
GAME_DIR="/absolute/path/to/openarena" ./evaluations/4-games/openarena/run.sh 30
GAME_DIR="/absolute/path/to/Hollow Knight" ./evaluations/4-games/hollow-knight/run.sh 45
GAME_DIR="/absolute/path/to/Hollow Knight" HOLLOW_USE_VULKAN=1 ./evaluations/4-games/hollow-knight/run.sh 45
```

`sources.json` 固定官方 x86-64 release 归档、版本、校验和与可执行文件路径。Hollow Knight 是付费专有游戏，artifact 不能下载或再分发其文件，因此下载清单明确排除它。合法持有副本的评审者仍可使用对应 runner。此时 `GAME_DIR` 应直接包含 `Hollow Knight` 可执行文件和 `Hollow Knight_Data/` 目录。

五个可再分发游戏均提供 vcpkg port。运行 `./evaluations/install-games.sh` 为每个游戏安装 AArch64 native 包和 x86-64 guest 包。没有单独的 Hecate 游戏包。Hecate 运行 guest 包内未经修改的程序，转换后的库来自 library evaluation。每个游戏的 `run.sh` 在启动前也会安装或复用自己的两个包。`GAMES_ROOT` 只用于旧版外部包布局。

watchdog 默认 30 秒。每个游戏的证据写入自身 `results/`。可写 home 位于 `.work/evaluations/games/runtime-home`，可用 `RUNTIME_HOME_ROOT` 覆盖。

共享 harness 启动游戏前会使用选定 devkit 构建 `_common/tests` 下的 x86-64 probe。所有游戏都会运行 XRandR probe，并验证 GL 与 Vulkan proc-address dispatch 能配合有序 thunk database 列表工作。OpenArena 额外运行 SDL 1.2 video probe，其他游戏运行 SDL2 display probe。build 输出、probe 日志和退出状态均写入游戏证据，preflight 失败时不会启动游戏。

MangoHud 默认包裹 host 侧 QEMU 进程，因为 AArch64 GL 和 Vulkan 工作在该进程执行。HUD 保持隐藏，同时每 100 ms 把样本写入 `results/<run-id>/mangohud`。完成的运行还包含 `fps-summary.json`，记录稳定 FPS 和 frametime 统计。设置 `MANGOHUD_ENABLED=0` 可关闭采集，`MANGOHUD_CONFIG_EXTRA` 可追加采集选项。

运行 `delete-all-results.sh --dry-run` 可在删除前查看可丢弃的游戏结果目录。`delete-all-reference-results.sh` 对参考结果提供相同的保护流程。
