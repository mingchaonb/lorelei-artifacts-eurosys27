# 论文数据 CSV

[English](README.md)

运行以下命令，把现有评测证据转换为绘图脚本直接读取的 CSV：

```bash
python3 evaluations/export-paper-data.py
```

默认读取每项 `results/` 中最新且包含可识别汇总的运行，输出到本目录。使用 `--output DIR` 改变输出目录。脚本不会运行 benchmark，也不会修改原始证据。

输出包括 `overall.csv`、`game-fps.csv`、`function-breakdown.csv`、`callback-track.csv`、`coverage-effort.csv` 和 `modifications.csv`。`manifest.json` 记录每个输入文件和 SHA-256。

`game-fps.csv` 读取每个游戏最新且可用的 MangoHud 日志，按固定 10 秒窗口统计 sample 数量、平均值、最小值、最大值和总体方差。该窗口从最后一个 sample 前第 12 秒开始，到第 2 秒结束。进入游戏场景仍需人工操作，但 review 表格由脚本自动计算。最新日志过短或格式错误时，表格会保留数据不足状态，不会换成更旧的结果。
