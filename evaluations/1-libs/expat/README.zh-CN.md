# Expat 2.8.2 验证（TLC + HLR）

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本配方通过仓库 vcpkg overlay 获取官方 Expat release，用 HLR 重写 7 个 production translation unit，在关闭 callback replacement 的情况下生成 TLC thunk，并在 native 与 Hecate 路径运行相同的定向 parser workload。

## 命令

```bash
./evaluations/1-libs/expat/run.sh
./evaluations/1-libs/expat/run.sh --reference --verbose
./evaluations/1-libs/expat/run.sh --install-only
```

devkit 未安装开发版模拟器时，可用 `QEMU=/path/to/qemu-x86_64` 选择。

## Workload 与范围

workload 解析 `<root><item>lorelei</item></root>`，并注册元素开始、元素结束和字符数据 callback。两条 lane 都必须出现 2 次开始 callback、2 次结束 callback、7 个文本字节，并以状态 0 退出。

配方验证该 workload 使用的 9 个 Expat API 和 3 种 callback 签名，不声明覆盖完整上游测试集。历史证据记录 3 个 CCG class、0 个 FDG class 和 1 个重写的 production 文件。每次新运行都会保留生成的 HLR 与 TLC 记录，以便重新审计这些值。
