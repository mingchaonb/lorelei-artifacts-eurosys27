# Hecate callback 地址边界比较

[English](README.md)

HLR 生成的 `__LoreFileContext_CCG()` 首先比较 callback 地址与 emulator 地址边界。host 地址不进入 guest trampoline 检查或 callback 重入路径，因此这一次整数地址比较就是常见 host callback 的快速路径。

本实验按生产代码中的同一判断方向测量该比较。输入使用固定大小的 `volatile` 地址数组，所有地址都位于 host 一侧。默认固定 CPU 0，运行 5 轮，每轮比较 100,000,000 次：

```bash
./evaluations/3-breakdown/hecate-callback-track/run.sh
```

可通过 `CPU`、`ROUNDS` 和 `ITERATIONS` 调整运行规模。结果保存每轮原始输出、已安装 `LoreHLR` 和 benchmark 的 SHA-256，以及 `summary.csv` 中的每次比较时间。这个数值只代表 host 地址的边界比较快速路径，不代表 guest callback trampoline 的完整重入成本。
