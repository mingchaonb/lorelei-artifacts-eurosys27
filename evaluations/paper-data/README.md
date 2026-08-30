# Paper-data CSV files

[中文版](README.zh-CN.md)

Convert existing evaluation evidence into CSV files consumed directly by the plotting scripts:

```bash
python3 evaluations/export-paper-data.py
```

The default reads the newest recognizable run under each item's `results/` and writes this directory. Use `--reference` to read `reference-results/` or `--output DIR` to select another destination. The exporter does not run benchmarks or modify raw evidence.

Outputs are `overall.csv`, `game-fps.csv`, `function-breakdown.csv`, `callback-track.csv`, `coverage-effort.csv`, and `modifications.csv`. A missing prerequisite or lane remains an explicit `missing` row instead of being filled with a legacy paper constant. `manifest.json` records every input path and SHA-256.

`game-fps.csv` reads each game's latest available MangoHud log. It reports the sample count, mean, minimum, maximum, and population variance over the fixed ten-second window from 12 seconds before the final sample up to 2 seconds before it. Game navigation remains manual, but computing the review table is automatic. A short or malformed latest log remains visible as insufficient evidence instead of being replaced with an older result.

Risotto performance, VA/FP statistics, and library distribution remain outside the current automatic export.
