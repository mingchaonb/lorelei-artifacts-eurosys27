# libX11 1.8.7

[English](README.md)

本配方把固定的 Ubuntu 24.04 libX11 source 构建为 native AArch64、x86-64 guest 和经 HLR 重写的 AArch64 package。定向 X11 测试检查非 variadic keysym 与 Xrm call，打开当前 X11 display，并对 XIM 与 XIC object 测试 resource-name variadic call。

```bash
./run.sh --reference
```

runner 默认继承当前环境的 `DISPLAY` 与 `XAUTHORITY`。需要覆盖当前图形会话时，可通过 `GUI_ENV` 指定一个同时包含这两个变量的文件。

- `--install-only` 安装并 audit 三个 package，生成 TLC thunk，不要求 active X11 session。
- `--reference` 将运行保存在 `reference-results`。
- `--verbose` 显示 vcpkg 准备输出并保留原始日志。

运行时只比较 native 与 Hecate，绝不运行纯 QEMU lane。这是定向 display integration workload，不是完整上游 suite，因此标题不含 `[ALL TESTS PASSED]`。
