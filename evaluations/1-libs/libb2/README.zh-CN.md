# libb2 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 libb2 0.98.1，运行共享库配置选定的全部 4 个上游 BLAKE2 known-answer 程序。production target 是 `libb2.so.1`。native AArch64 与 x86-64 guest 包从同一官方源码构建为共享库。

Hecate lane 使用 TLC 生成的 GTL 与 HTL 库，不启用 `hlr` feature，不调用 LoreHLR，不加载 HLR extension，也不声明 workload 外 API。OpenMP 与 architecture dispatch 均关闭。

vcpkg port 将 4 项测试全部安装到 `tools/libb2/upstream-tests`。`run.sh` 只使用安装后的 package，不从源码树或 vcpkg buildtree 重建。清理前验证显示 4 项测试在 native 与 Hecate 均通过且输出相同，没有配置 skip 或 failure。

runner 从 `LORELEI_DEVKIT` 读取 devkit，默认使用仓库内 `.work/devkit`。`--install-only` 在两个包完成安装和 audit 后停止，`--reference` 写入只追加参考证据，`--verbose` 显示 vcpkg 准备输出并保留原始日志。不提供纯 QEMU lane。

```bash
./run.sh --reference
```
