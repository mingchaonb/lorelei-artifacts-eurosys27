# Paper-data CSV files

[中文版](README.zh-CN.md)

Convert existing evaluation evidence into CSV files consumed directly by the plotting scripts:

```bash
python3 evaluations/export-paper-data.py
```

The default reads the newest recognizable run under each item's `results/` and writes this directory. Use `--output DIR` to select another destination. The exporter does not run benchmarks or modify raw evidence.

Outputs are `overall.csv`, `game-fps.csv`, `function-breakdown.csv`, `callback-track.csv`, `coverage-effort.csv`, and `modifications.csv`. `manifest.json` records every input path and SHA-256.

`game-fps.csv` reads the latest available MangoHud log independently for each game and each of the native, QEMU-Hecate, Box64, and Box64-Hecate lanes. It reports physical-GPU status, retained and ignored sample counts, mean, minimum, maximum, and population variance over the fixed ten-second window from 12 seconds before the final sample up to 2 seconds before it. Samples above 300 FPS are treated as measurement noise and excluded before computing statistics. Game navigation remains manual, but computing the review table is automatic. A short or malformed latest log remains visible as insufficient evidence instead of being replaced with an older result.
