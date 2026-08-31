# libcrc 2.0 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方通过固定版本的 vcpkg overlay 安装 libcrc 2.0 和上游测试，生成 TLC thunk，再在 native 与 Hecate lane 运行安装后的测试。

```bash
./evaluations/1-libs/libcrc/run.sh
./evaluations/1-libs/libcrc/run.sh --install-only
```

port 构建完整上游 `testall`，包括其 CRC 与 NMEA translation unit，并安装到 `tools/libcrc/upstream-tests`。安装后的测试在两条 lane 均报告 `All tests succeeded`，且输出相同。不从源码树重建，也不运行纯 QEMU lane。
