# monocypher 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 monocypher 4.0.3，验证上游 `test.out` vector suite 使用的 API。production target 为 `libmonocypher.so.4`，两个架构从同一官方源码构建共享库。Hecate 使用 TLC GTL 与 HTL，不启用 HLR。core 与可选 Ed25519 实现都在被测 DSO 中。

port 构建并安装完整上游 vector test。`run.sh` 只使用安装后的 package，运行 native 与 Hecate，绝不运行纯 QEMU lane。两条 lane 均以状态 0 退出且输出等价即为成功。

```bash
./run.sh --reference
```
