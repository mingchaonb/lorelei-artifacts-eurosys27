# libunibreak 7.0 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

workload 使用 release conformance vector，以 line、word 和 grapheme 三种模式运行上游 `tests` 程序。每种模式都必须在 native 与 Hecate 成功退出。

只声明共享库和 workload 使用的 UTF-8 break API。文档与 static output 排除，不使用 HLR。

运行 `./evaluations/1-libs/libunibreak/run.sh` 安装两个架构、生成 TLC thunk，并在两条 lane 运行上游程序的全部三种模式。port 将程序与 3 份 conformance vector 安装到 `tools/libunibreak/upstream-tests`，`--install-only` 在安装和 thunk 生成后停止。
