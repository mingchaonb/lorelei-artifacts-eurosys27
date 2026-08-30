# SDL2_image 2.8.12 验证（TLC + HLR）

[English](README.md)

本配方构建官方 SDL2_image 2.8.12 共享库和固定的 SDL2 2.28.5 依赖。workload 先为内存中的 two-pixel PNM 创建 `SDL_RWops`，再加载官方 release 携带的 14 个 fixture，覆盖本 build 启用的 BMP、GIF、CUR、ICO、PCX、PNM、QOI、TGA、XCF、XPM 与 SVG 路径。两条 lane 都必须每个 fixture 输出一条 pass，最终输出 `image-load:pass fixtures=14` 并以状态 0 退出。

```bash
./evaluations/1-libs/sdl2-image/run.sh --reference --verbose
```

Hecate 对 SDL2 与 SDL2_image 均使用 TLC 加 HLR，并关闭 TLC callback replacement。SDL2 使用仅 dummy 的 host 配置。SDL2_image 启用内置 BMP、GIF、LBM、PCX、PNM、QOI、SVG、TGA、XCF、XPM 与 XV loader，关闭外部 codec。经过审查的 patch 让内部 static format-detector table 保持原始 host 地址。官方测试是交互 image viewer，本配方把可用 fixture 用于非交互 regression。release 没有 LBM 与 XV fixture，因此二者未测试。预期 audit 为 20 个 translation unit、1 个 CCG class、1 个 FDG class 和 1 个重写文件。
