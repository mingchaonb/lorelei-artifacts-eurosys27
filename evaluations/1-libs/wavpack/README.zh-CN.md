# WavPack 5.9.0 验证（TLC + HLR）

[English](README.md)

本配方构建官方 WavPack 5.9.0 共享库，并将上游 `wvtest` 安装到 `tools/wavpack/upstream-tests`。它对 native 库和 Hecate 路径运行 `wvtest --exhaustive --short --no-extras`。两条 lane 均须连续出现 `test 0001` 至 `test 0164`、以状态 0 退出，并最终输出 `all tests pass`。

```bash
./evaluations/1-libs/wavpack/run.sh --reference --verbose
```

TLC callback replacement 已关闭，HLR 重写 production 共享库 closure。仓库 manifest 注册 `WavpackBlockOutput` callback ABI 作为 metadata anchor，经过审查的 patch 导出该 anchor 与 HLR file context，并让 host 内部 static callback 保持原始 host 地址。`wvtest` 测试 threaded encoding，因此 thread hook 保持启用。`--short` 排除长时间 variant，`--no-extras` 排除可选额外 scenario。预期 audit 为 23 个 translation unit、6 个 CCG class、3 个 FDG class 和 10 个重写文件。
