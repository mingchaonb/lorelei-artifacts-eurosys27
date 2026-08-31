# murmurhash 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 murmurhash 0.2.0，验证 19 项上游 known-answer case 使用的 API。production target 为 `libmurmurhash.so`，两个架构从同一官方源码构建共享库。Hecate 使用 TLC GTL 与 HTL，不启用 HLR，测试程序动态链接共享库。

port 构建并安装完整 19-case 上游测试。`run.sh` 只使用安装后的 package，运行 native 与 Hecate，绝不运行纯 QEMU lane。两条 lane 均以状态 0 退出且输出等价即为成功。

```bash
./run.sh
```
