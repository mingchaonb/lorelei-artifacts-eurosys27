# PCRE2 POSIX 10.46 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定 vcpkg overlay 获取官方 PCRE2 POSIX 10.46 release，为两个架构构建共享库和全部配置测试，安装测试并生成 TLC thunk，再在 native 与 Hecate lane 运行相同 suite。不使用 HLR，也不运行纯 QEMU lane。

```bash
./evaluations/1-libs/pcre2-posix/run.sh
./evaluations/1-libs/pcre2-posix/run.sh --reference --verbose
./evaluations/1-libs/pcre2-posix/run.sh --install-only
```

port 将注册的上游 `pcre2posix_test` 安装到 `tools/pcre2-posix/upstream-tests`，`run.sh` 只运行该安装测试。目标只包括 libpcre2-posix，8-bit PCRE2 DSO 是 host 侧依赖。JIT、core ABI 与 utilities 排除。
