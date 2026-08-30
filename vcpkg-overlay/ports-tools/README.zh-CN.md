# AE 工具 ports

[English](README.md)

本 overlay 包含 evaluation harness 使用的可执行工具。它与保存被测库及其 Hecate 构建配方的 `../ports` 分开。

模拟器 port 固定到 `mingchaonb` fork 中经过审查的 commit，只把公开 evaluation 路径需要的程序安装到 `tools/<port>/`。仓库级安装器还选用 vcpkg 内置 FFmpeg port，因此 native FFmpeg 命令不由 Hecate 库测试配方构建。

`box64-ae` 是性能评测使用的不带插桩版本。`box64-callback-track-ae` 是独立的测量版本，包含 callback 地址来源 breakdown 所需的计时探针。分开打包可以避免插桩影响普通 Box64 性能数据。

一次性安装 host 构建依赖：

```bash
sudo apt install -y build-essential clang cmake ninja-build pkg-config python3 libglib2.0-dev libdw-dev
```

从任意当前目录运行公开安装器：

```bash
./evaluations/install-tools.sh
```

安装后的程序路径为：

1. `vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64`
2. `vcpkg/installed/arm64-linux/tools/blink-ae/blink`
3. `vcpkg/installed/arm64-linux/tools/box64-ae/box64`
4. `vcpkg/installed/arm64-linux/tools/box64-callback-track-ae/box64-callback-track`
5. `vcpkg/installed/arm64-linux/tools/fex-ae/FEX`
6. `vcpkg/installed/arm64-linux/tools/ffmpeg/ffmpeg`
