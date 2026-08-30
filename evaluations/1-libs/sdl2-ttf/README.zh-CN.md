# SDL2_ttf 2.24.0 验证（TLC + HLR audit）

[English](README.md)

本配方使用 FreeType、不使用 HarfBuzz 构建官方 SDL2_ttf 2.24.0。该 release 没有注册自动 CMake 测试，因此 port 在 `tools/sdl2-ttf/upstream-tests` 安装一个定向 text-size 测试和校验和固定的 DejaVu Sans 字体。测试在 native 与 Hecate 输出必须相同。

```bash
./evaluations/1-libs/sdl2-ttf/run.sh --reference --verbose
```

Hecate 使用 SDL2 的 TLC 加 HLR 依赖路径，并为 SDL2_ttf 使用 TLC thunk。HLR 仍在关闭 callback replacement 的情况下 audit 准确的 SDL2_ttf shared target。预期结果为 1 个 translation unit、0 个 CCG class、0 个 FDG class 和 0 个重写文件，因此 SDL2_ttf 是已 audit 的 zero-hit 项，不计为 HLR-transformed DSO。

运行普通 `run.sh` 安装两个架构、生成 thunk 并运行定向测试。`--install-only` 在 package 安装、HLR audit 与 thunk 生成后停止。该定向 workload 不声明上游 all-tests，因此标题没有 all-tests 标记。
