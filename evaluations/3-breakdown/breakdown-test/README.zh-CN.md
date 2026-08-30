# 2 参数与 6 参数函数调用开销拆分

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本 benchmark 测量 `breakdown-test` port 提供的 2 参数和 6 参数函数。两个函数都只返回首个参数，因此 host 函数体接近空操作，同时可以观察参数数量对打包和传输成本的影响。

先从 `1-libs` 安装 port，再运行 breakdown：

```bash
../../1-libs/breakdown-test/run.sh --install-only
./run.sh
```

breakdown runner 只使用 `evaluations/1-libs/breakdown-test` 生成的 vcpkg 安装，不会调用 vcpkg。每轮分别执行一百万次 2 参数调用和一百万次 6 参数调用，默认运行五轮。原始输出、环境信息和按参数数量分组的中位数汇总写入 `results/<UTC timestamp>/`。

计时需要 `install-tools.sh` 安装的独立 `qemu-breakdown-ae`。它包含识别 guest 计时标记和记录四个阶段的探针，不用于命令行性能评测。可通过 `QEMU_BREAKDOWN=/absolute/path/to/qemu-x86_64` 覆盖。
