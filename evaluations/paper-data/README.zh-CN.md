# 论文数据 CSV

[English](README.md)

运行以下命令，把现有评测证据转换为绘图脚本直接读取的 CSV：

```bash
python3 evaluations/export-paper-data.py
```

默认读取每项 `results/` 中最新且包含可识别汇总的运行，输出到本目录。使用 `--output DIR` 改变输出目录。脚本不会运行 benchmark，也不会修改原始证据。命令行负载和游戏两部分是逐条 lane 分别选取最新运行的，因此同一张表的各行可能来自不同批次，导出器也不检查这些运行是否使用同一台机器、同一版本工具和同一组参数。`manifest.json` 列出了每一行对应的输入文件，其路径带有所属运行的目录名，可据此确认一张表是否来自同一批次。

输出包括 `overall.csv`、`game-fps.csv`、`function-breakdown.csv`、`callback-track.csv`、`coverage-effort.csv` 和 `modifications.csv`。`manifest.json` 记录每个输入文件和 SHA-256。

`game-fps.csv` 分别读取每个游戏在 native、QEMU-Hecate、Box64 和 Box64-Hecate 四条 lane 中最新且可用的 FPS 采样日志，按固定 10 秒窗口统计物理 GPU 状态、保留与忽略的 sample 数量、平均值、最小值、最大值和总体方差。该窗口从最后一个 sample 前第 12 秒开始，到第 2 秒结束。计算统计量前，导出器将超过 10000 FPS 的 sample 作为测量噪声忽略。这个上限在开启 VSync 时是 300 FPS，关闭 VSync 与游戏内帧率上限之后调高，因为此时多条 lane 的真实帧率会超过 300 乃至 1000 FPS。进入游戏场景仍需人工操作，但 review 表格由脚本自动计算。最新日志过短或格式错误时，表格会保留数据不足状态，不会换成更旧的结果。
