# nettle 验证（仅 TLC）

[English](README.md)

本配方固定 nettle 3.10.2，运行当前上游 `make check` 配置选择的全部测试。production target 为 `libnettle.so.8`。两条执行路径是安装后的 native AArch64 package，以及安装后的 x86-64 测试加 TLC GTL 和 native AArch64 库组成的 Hecate。

port 将配置 suite 安装到 `tools/nettle/upstream-tests`。`run.sh` 只使用这些安装测试与 package，不从源码树或 buildtree 重建。package 还包含 test manifest、fixture、runner、TLC description 与 suite 需要的 guest-local read-only metadata。

清理前验证中两条 lane 分类相同：75 项通过、5 项由共享 build 配置跳过、0 项失败。配置关闭 public-key、assembler、OpenSSL integration、文档和静态库，因此 public-key helper、3 个 RSA example 和 x86 IBT probe 在两条 lane 同样跳过，它们是配置排除而非 Hecate 失败。

```bash
./run.sh
```
