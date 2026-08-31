# libcorrect 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 libcorrect snapshot `ee82e667`，验证 4 个 convolutional 与 Reed-Solomon runner 使用的 API。production target 是 `libcorrect.so` 和 `libfec.so`。native AArch64 与 x86-64 guest 包从相同官方源码构建为共享库。

Hecate lane 使用 TLC 生成的 GTL 与 HTL 库，不启用 `hlr` feature，不调用 LoreHLR，不加载 HLR extension，也不声明 workload 外 API。同一源码包提供两个独立 ABI target，因此 benchmark 数量为 2。

runner 从 `LORELEI_DEVKIT` 读取 devkit，默认使用仓库内 `.work/devkit`。`--install-only` 在两个共享包构建并 audit 后停止。生成的 audit 会记录 DATA、TLS、allocator ownership、callback、errno、symbol version、SONAME 和动态依赖，即使其中某类在 workload 中没有命中。

vcpkg port 构建并安装当前配置的全部 4 个上游 test runner。`run.sh` 只使用安装后的 package，在 native 与 Hecate 运行，绝不运行纯 QEMU lane。两条 lane 均以状态 0 退出且输出等价即为成功。

```bash
./run.sh
```
