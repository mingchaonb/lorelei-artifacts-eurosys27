# libthai 0.1.30 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方使用唯一的共享 `libdatrie` overlay 依赖，并把 libthai 构建为共享 DSO。port 在打包时使用 host `trietool`，使目标 package 包含生成的上游 dictionary。它运行 9 项上游 character、cell、input、rendering、string、wide-character、sorting 和 word-break 测试，sorting 输出必须与固定 expected 文件一致。

文档生成与静态库排除。为便于 thunk 解析，在必要位置抑制 public predicate macro。不创建第二个 datrie port，也不使用 HLR。

运行 `./evaluations/1-libs/libthai/run.sh` 安装两个架构、生成 TLC thunk 并在 native 与 Hecate 运行全部 9 项测试。port 将测试程序和 sorting 输入安装到 `tools/libthai/upstream-tests`，`--install-only` 在安装和 thunk 生成后停止。
