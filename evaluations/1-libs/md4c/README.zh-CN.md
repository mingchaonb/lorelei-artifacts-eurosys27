# MD4C 0.5.3 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 获取官方 MD4C 0.5.3 release，为两个架构构建共享库和全部配置测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同 suite。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/md4c/run.sh
./evaluations/1-libs/md4c/run.sh --reference --verbose
./evaluations/1-libs/md4c/run.sh --install-only
```

parser 作为 HTML DSO 依赖被调用。port 将全部 818 项配置的 spec、regression、extension 与 pathological case 所需 driver、脚本和数据安装到 `tools/md4c/upstream-tests`。`run.sh` 对称运行该安装 suite，不从源码树重建。
