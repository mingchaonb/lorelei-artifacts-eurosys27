# qrencode 4.1.1 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方只构建共享 QR encoding 库，关闭 PNG 与命令行工具。port 在 native 与 Hecate 运行当前配置的全部 12 项上游 algorithm 测试，没有配置测试被排除。

thunk surface 从测试程序推导，port 中紧凑的 public smoke surface 覆盖 encoding 与 release。PNG output 和上游 CLI 排除，不使用 HLR。

运行 `./evaluations/1-libs/qrencode/run.sh` 安装两个架构、生成 TLC thunk 并运行 12 项测试。port 将全部测试 binary、helper DSO、内部测试 header 与 frame input 安装到 `tools/qrencode/upstream-tests`。源码 patch 让库自身 allocation 与 `errno` observation 保持在 host，共享 allocator libc shim 处理跨 thunk boundary 的 ownership。`--install-only` 在安装和 thunk 生成后停止。
