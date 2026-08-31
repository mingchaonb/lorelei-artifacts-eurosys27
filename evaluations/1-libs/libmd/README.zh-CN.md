# libmd 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 libmd 1.2.0，验证 7 个 digest 程序使用的 API。production target 是 `libmd.so.0`。native AArch64 与 x86-64 guest 包从相同官方源码构建为共享库。

Hecate lane 使用 TLC 生成的 GTL 与 HTL，不启用 `hlr`，不调用 LoreHLR，不加载 HLR extension，也不声明 workload 外 API。guest thunk 必须保留 `LIBMD_0.0`、`LIBMD_0.1` 和 `LIBMD_0.2` symbol version。

runner 从 `LORELEI_DEVKIT` 读取 devkit，默认使用 `.work/devkit`。`--install-only` 在两个共享包构建并 audit 后停止。生成的 audit 记录 DATA、TLS、allocator ownership、callback、errno、symbol version、SONAME 和动态依赖，即使某类没有 workload hit。

port 构建并安装全部 7 项上游 digest 测试。`run.sh` 只使用安装后的 package，运行 native 与 Hecate，绝不运行纯 QEMU lane。两条 lane 均以状态 0 退出且输出等价即为成功。

```bash
./run.sh
```
