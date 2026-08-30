# 函数覆盖率审计

本评测把每个实际 DSO 的完整动态函数导出集合交给 TLC，并记录 TLC 能够从完整上游 headers 解析的函数。它不使用命令行 workload 的 API 白名单。

运行：

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
```

原始 Symbols、聚合 Desc、TLC 命令、日志和 `ThunkStat.json` 写入 `results/<run-id>/libraries/`。`summary.csv` 汇总每个 DSO 的导出函数数、Hecate 支持函数数、未支持函数数和覆盖率。

人工配置行数由 `evaluations/export-paper-data.py` 独立统计。该口径包含人工维护配置中的 include 行，不包含本审计生成的 Symbols、聚合 Desc 或 thunk 源码。
