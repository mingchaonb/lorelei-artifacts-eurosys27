# SDL2_mixer 2.8.2 验证（TLC + HLR）

[English](README.md)

本配方构建官方 SDL2_mixer 2.8.2 共享库和固定 SDL2 2.28.5 依赖。定向 workload 通过 SDL dummy audio driver 播放 raw mono chunk，并注册 post-effect callback 与 completion callback。native 与 Hecate 都必须至少调用一次 effect、恰好调用一次 completion，并以状态 0 退出。

```bash
QEMU=/path/to/qemu-x86_64 \
  ./evaluations/1-libs/sdl2-mixer/run.sh --verbose
```

Hecate 对 SDL2 与 SDL2_mixer 使用 TLC 加 HLR，并关闭 TLC callback replacement。host 预加载 Lorelei QEMU thread hook，因为 SDL 从 native dummy-audio thread 调用 guest callback。port 保留 WAVE 支持，关闭可选外部 music codec。该 workload 验证跨 host-created thread 的 effect callback，不声明覆盖所有 decoder 或完整上游 suite。预期 audit 为 26 个 translation unit、2 个 CCG class、2 个 FDG class 和 3 个重写文件。
