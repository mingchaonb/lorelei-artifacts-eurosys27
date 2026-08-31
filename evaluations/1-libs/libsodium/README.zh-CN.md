# libsodium 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 libsodium 1.0.20，验证当前上游 `make check` suite 使用的 API。production target 为 `libsodium.so.26`。native AArch64 与 x86-64 guest 从相同官方源码构建为共享库。Hecate 使用 TLC GTL 与 HTL，不启用 HLR。assembly dispatch 已关闭，使两条 lane 使用同一 portable implementation。

port 读取当前配置的上游 `TESTS` 列表，构建并安装全部 80 个程序及 fixture。`run.sh` 只使用安装后的 package，不运行纯 QEMU lane。预期结果是 80 项测试在 native 与 Hecate 全部通过。

```bash
./run.sh
```
