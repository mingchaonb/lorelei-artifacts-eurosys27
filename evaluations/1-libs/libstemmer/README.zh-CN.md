# libstemmer 3.1.1 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

port 从上游 PIC object 构建真实共享库 `libstemmer.so.0`，不会把 Snowball static archive 当成交付物。workload 动态链接上游 `stemwords`，并对固定的 `snowball-data` commit `a0ec0d0a2839ec885878868de20fcb63209d92b0` 运行 57 项语言和 encoding 检查。归档 SHA-512 为 `de068e9521e339595e0805fc4524a972a8862ccc47b4731f98913f4663bdd08e1608c28183d82af1de435ac6610b3a80cac19adfcc088119d6ebe4c319c8e41b`。

所有生成的 stemming 检查必须在 native 与 Hecate 通过。Snowball compiler selftest 不属于 DSO 声明，不使用 HLR。运行 `./evaluations/1-libs/libstemmer/run.sh` 安装两个架构、生成 TLC thunk 并运行全部 57 项检查。port 将 `stemwords` 与固定 corpus 安装到 `tools/libstemmer/upstream-tests`，`--install-only` 在安装和 thunk 生成后停止。
