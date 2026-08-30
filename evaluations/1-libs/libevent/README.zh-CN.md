# libevent 2.1.12-stable 验证（TLC + HLR）

[English](README.md)

本配方只构建 `libevent_core` DSO context。定向 workload 使用 `EV_TIMEOUT` 激活一个 no-fd event，要求 native 与 Hecate 路径都恰好执行一次 guest callback。TLC callback replacement 已关闭。lock、DNS stress 与完整上游 suite 不属于本声明范围。

```bash
./evaluations/1-libs/libevent/run.sh --reference --verbose
```

预期 audit 为 19 个 translation unit、1 个 CCG class、1 个 FDG class 和 6 个重写文件。
