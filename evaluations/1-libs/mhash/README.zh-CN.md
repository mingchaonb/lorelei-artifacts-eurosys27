# mhash 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方固定 mhash 0.9.9.9，验证 driver、HMAC、keygen、restart 与 fragmentation 测试使用的 API。production target 为 `libmhash.so.2`，两个架构从同一官方源码构建共享库。Hecate 使用 TLC GTL 与 HTL，不启用 HLR。port 更新 GNU `config.guess` 与 `config.sub` 以支持 AArch64。

port 构建并安装全部 5 项配置测试及 driver 脚本。`run.sh` 只使用安装后的 package，运行 native 与 Hecate，绝不运行纯 QEMU lane。两条 lane 均以状态 0 退出且输出等价即为成功。

```bash
./run.sh --reference
```
