# Paper-data CSV files

[中文版](README.zh-CN.md)

Convert existing evaluation evidence into CSV files consumed directly by the plotting scripts:

```bash
python3 evaluations/export-paper-data.py
```

The default reads the newest recognizable run under each item's `results/` and writes this directory. Use `--output DIR` to select another destination. The exporter does not run benchmarks or modify raw evidence. For the command-line workloads and the games, the newest run is chosen separately for every lane, so rows of one table can come from different runs, and the exporter does not check that those runs share a host, tool versions, or parameters. `manifest.json` lists the input file behind every row, and its path names the run directory it came from, which is how to confirm that a table was assembled from a single batch.

Outputs are `overall.csv`, `game-fps.csv`, `function-breakdown.csv`, `callback-track.csv`, `coverage-effort.csv`, and `modifications.csv`. `manifest.json` records every input path and SHA-256.

`game-fps.csv` reads the latest available FPS sample log independently for each game and each of the native, QEMU-Hecate, Box64, and Box64-Hecate lanes. It reports physical-GPU status, retained and ignored sample counts, mean, minimum, maximum, and population variance over the fixed ten-second window from 12 seconds before the final sample up to 2 seconds before it. Samples above 10000 FPS are treated as measurement noise and excluded before computing statistics. The bound was 300 FPS while VSync was on, and was raised once VSync and the in-game frame caps were disabled, because several lanes then legitimately exceed both 300 and 1000 FPS. Game navigation remains manual, but computing the review table is automatic. A short or malformed latest log remains visible as insufficient evidence instead of being replaced with an older result.
