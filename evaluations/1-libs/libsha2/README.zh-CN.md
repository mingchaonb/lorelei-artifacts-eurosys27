# libsha2 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定没有 release tag 的 libsha2 snapshot `565f650`，验证 37 项上游 SHA-256 检查使用的 API。production target 为 `libsha2.so`，native AArch64 与 x86-64 guest 包从相同官方源码构建为共享库。Hecate 使用 TLC 生成的 GTL 与 HTL，不启用 HLR，也不声明 workload 外 API。

port 构建并安装完整的 37-check 上游测试。`run.sh` 只使用安装后的 package，运行 native 与 Hecate，绝不运行纯 QEMU lane。两条 lane 均以状态 0 退出且输出等价即为成功。`--install-only` 在构建与 audit 后停止。

```bash
./run.sh
```
