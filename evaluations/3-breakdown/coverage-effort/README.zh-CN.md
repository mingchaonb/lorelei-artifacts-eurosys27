# 函数覆盖率审计

本评测比较 20 个实际 DSO 的 Hecate 与 Box64 函数覆盖率和人工配置行数。它把每个 DSO 的完整动态函数导出集合交给 TLC，并记录 TLC 能够从完整上游 headers 解析的函数，不使用命令行 workload 的 API 白名单。

评测集合包括：

- 压缩库：zlib、zstd、bzip2、Brotli 和 LZMA
- 多媒体库：FFmpeg 的 avformat、avcodec 和 avutil，以及 Ogg、Opus 和 libsndfile
- 图形与窗口系统库：SDL2、Vulkan、OpenGL、X11 和 XCB
- 通用系统库：Expat、curl、libevent 和 IDN2

运行：

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
```

原始 Symbols、聚合 Desc、TLC 命令、日志和 `ThunkStat.json` 写入 `results/<run-id>/libraries/`。X11、XCB、Vulkan 和 OpenGL 复用各自 port 安装的完整导出审计，并同时记录审计来源。`summary.csv` 汇总每个 DSO 的导出函数数、Hecate 支持函数数、未支持函数数和覆盖率。

人工配置行数由 `evaluations/export-paper-data.py` 独立统计。该口径包含人工维护配置中的 include 行，不包含本审计生成的 Symbols、聚合 Desc 或 thunk 源码。Box64 manual LOC 还包含以 `//` 禁用的 `GO`、`GOM`、`GO2`、`GOW`、`GOWM`、`GOS` 和数据 wrapper 声明，因为这些行属于人工维护工作。它们直接计入 `box64_manual_loc`，但不进入 Box64 coverage 的支持函数集合。普通说明性注释不计入 LOC。
