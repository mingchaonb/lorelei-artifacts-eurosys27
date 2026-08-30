# SDL 1.2 HLR 评测

[English](README.md)

本配方固定 Ubuntu 24.04 的 SDL 1.2 实现 `sdl12-compat` 1.2.68，使用 HLR 重写 production 源码，生成 OpenArena 使用的 SDL 1.2 thunk，并通过 Hecate 运行定向 x86-64 guest 测试。

```bash
QEMU=/path/to/patched/qemu-x86_64 \
  ./evaluations/1-libs/sdl1/run.sh
```

测试覆盖 dummy video 初始化、从 host 创建的 SDL2 thread 到达的 SDL 1.2 audio callback，以及保持在 guest address space 的 `SDL_LoadObject` 与 `SDL_LoadFunction`。`--install-only` 为图形游戏 runner 准备 host package 和 thunk，不执行 QEMU。build product 位于 `.work/evaluations/sdl1`，证据只追加到 `evaluations/1-libs/sdl1/results`。
