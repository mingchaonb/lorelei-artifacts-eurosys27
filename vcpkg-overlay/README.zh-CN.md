# Lorelei AE vcpkg overlay

[English](README.md)

本目录是 v2 library 验证共用的包管理层。所有被测库使用 `ports/` 下的 port，所有 AE 目标配置使用 `triplets/` 下的 triplet。

只支持仓库根目录内的 `vcpkg/` checkout，固定版本为 `2026.07.29`。

## 初始设置

```bash
git clone https://github.com/microsoft/vcpkg.git vcpkg
git -C vcpkg checkout 2026.07.29
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

包配方不会自行 clone 上游项目。port 固定上游 release 和校验和，此后的下载、解压、patch、构建、安装和 package cache 均由 vcpkg 管理。

## 目录结构

```text
vcpkg-overlay/
├── ports/
│   └── sdl2/
├── ports-tools/
│   ├── blink-ae/
│   ├── box64-ae/
│   ├── box64-callback-track-ae/
│   ├── fex-ae/
│   └── qemu-ae/
└── triplets/
    ├── arm64-linux-ae.cmake
    ├── x64-linux-ae.cmake
    └── x64-linux-ae-toolchain.cmake
```

runner 显式传入 `--overlay-ports` 和 `--overlay-triplets`。独立安装根允许 TLC 与 HLR 打包不同的 host build，而不会互相覆盖。

## 直接安装包

公开库配方通常会运行这些命令，也可以直接用于包级诊断：

```bash
./vcpkg/vcpkg install \
  'sdl2[tests]:arm64-linux-ae' \
  --overlay-ports=vcpkg-overlay/ports \
  --overlay-triplets=vcpkg-overlay/triplets
```

公开 evaluation runner 读取 `LORELEI_DEVKIT` 并向 vcpkg 导出同名值。直接安装 guest 或 HLR 包时必须显式提供该变量：

```bash
export LORELEI_DEVKIT=/path/to/devkit
./vcpkg/vcpkg install \
  'sdl2[tests]:x64-linux-ae' \
  --overlay-ports=vcpkg-overlay/ports \
  --overlay-triplets=vcpkg-overlay/triplets
```

可执行基础工具位于独立的 `ports-tools` overlay。公开安装器组合四个普通模拟器 port、独立插桩的 Box64 callback breakdown port 和 vcpkg 内置的 native FFmpeg port：

```bash
./evaluations/install-tools.sh
```
