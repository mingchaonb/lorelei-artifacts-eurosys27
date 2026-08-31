# zstd 1.5.7 验证（仅 TLC）

[English](README.md)

本配方通过固定 vcpkg overlay 安装 zstd 1.5.7 和上游测试，生成 TLC thunk，再在 native 与 Hecate lane 运行选定的安装测试。

```bash
./evaluations/1-libs/zstd/run.sh
./evaluations/1-libs/zstd/run.sh --install-only
```

port 将上游 CMake 的全部 4 项注册及 runtime data 安装到 `tools/zstd/upstream-tests`。native 与 Hecate 对称运行其中 3 项，并把 `fuzzer` 记为基线跳过，因为固定 30,000-iteration stress campaign 不属于 AE functional scope。`fullbench` 仍用 1 次 timing iteration 和有界 sample 测试所有注册函数，因为默认重复主要用于性能而非额外正确性覆盖。随机 `zstreamtest` 使用固定 seed 和 100 次 functional iteration，而非 10,000 次 stress 默认值。test CLI 关闭 asynchronous I/O worker，共享库仍保留 multithreading。

窄范围 subtest 排除包括 `zstreamtest` 的 guest callback，以及 `playTests.sh` 中 3 个 dictionary-training section，因为 thunk boundary 不支持其 pointer semantics。不从源码树重建，也不运行纯 QEMU lane。
