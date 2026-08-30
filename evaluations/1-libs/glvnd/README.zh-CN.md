# 系统 libGL 验证

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本配方使用系统已安装的 libglvnd DSO。`glvnd` overlay port 不构建或复制 libglvnd。它的 CMake project 生成并安装相互独立的 legacy GL、direct GLX 和 X11 thunk pack、native 与 x86_64 验证程序、`ThunkDB.json` 和 TLC audit 输出。evaluation 脚本只安装该 port、运行打包程序并收集证据。

测试在当前 X server 创建 GLX pbuffer context，通过 `glXGetProcAddressARB` 解析 OpenGL 函数，写入 mapped GL buffer，并在驱动支持时测试 OpenGL debug callback。一个程序只链接 legacy `libGL.so.1` 入口，另一个对 `libGLX.so.0` 和 `libGL.so.1` 都有直接 `DT_NEEDED`，用于验证独立 GLX forward thunk。port 依赖 `libx11[hlr]`，并将匹配的 X11 thunk 与两个 graphics thunk 一起打包。
