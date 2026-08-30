# GNU Libidn2 2.3.8 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 获取官方 GNU Libidn2 2.3.8 release，为 AArch64 与 x86-64 构建共享库和全部配置测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同 suite。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/libidn2/run.sh
./evaluations/1-libs/libidn2/run.sh --reference --verbose
./evaluations/1-libs/libidn2/run.sh --install-only
```

build 使用 bundled libunistring。port 将全部 15 项配置测试安装到 `tools/libidn2/upstream-tests`，包括 CLI 脚本和 3 个 fuzz-harness 程序。Hecate 加载共享 allocator libc shim，使 host 库返回的 buffer 在同一 heap 释放。仅用于测试的 port patch 将 `test-IdnaTest-txt` 中的 `getline(FILE *)` 替换为等价且有界的 `fgets` loop，因为 shim 不支持该 `getline` stdio surface。`run.sh` 对称运行安装 suite，不从源码树重建。文档与 NLS 仍然排除。
