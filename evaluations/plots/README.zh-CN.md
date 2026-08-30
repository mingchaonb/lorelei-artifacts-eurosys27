# CSV 绘图脚本

[English](README.md)

本目录的脚本只读取 `evaluations/export-paper-data.py` 生成的 CSV，不包含论文数值常量。先导出数据，再构图：

```bash
python3 evaluations/export-paper-data.py
python3 evaluations/plots/plot-overall.py
python3 evaluations/plots/plot-coverage-effort.py
python3 evaluations/plots/plot-function-breakdown.py
python3 evaluations/plots/plot-callback-track.py
```

默认输出到 `.work/paper-figures/`。每个脚本支持 `--csv PATH`、`--output PATH` 和 `--show`。CSV 中的 `missing` 不会用旧论文值填补，图中会保留明确缺口。
