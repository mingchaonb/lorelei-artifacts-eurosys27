# libsyn123 1.33.7 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

本配方将固定官方 release 构建为 AArch64 host 与 x86_64 guest 共享库，生成 TLC thunk，并在 native 与 Hecate 运行相同定向 public-API workload。不使用 HLR。

```bash
./evaluations/1-libs/libsyn123/run.sh
./evaluations/1-libs/libsyn123/run.sh --reference --verbose
./evaluations/1-libs/libsyn123/run.sh --install-only
```

workload 创建 synthesis handle，将负 6 dB 转成 linear factor 后再转换回来，验证 roundtrip 并销毁 handle。两条 lane 均须报告 error 0 和恢复出的负 6 dB。`libsyn123.so.0` 是 mpg123 release 独立提供的 DSO，`libmpg123` decoder 由另一 port 评测。

port 将当前配置的上游 `resample_total` 测试安装到 `tools/libsyn123/upstream-tests`。定向 workload 后两条 lane 均通过 1/1。decoder 测试属于 mpg123 port。不运行纯 QEMU lane。
