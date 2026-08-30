# SQLite 3.53.4 验证（TLC + HLR）

[English](README.md)

本配方下载官方 SQLite 3.53.4 amalgamation，以 `sqlite3.c` 作为唯一 production translation unit。内存定向 workload 覆盖 `sqlite3_exec` row callback、custom SQL scalar function 与 update hook。native 与 Hecate 都必须报告 1 row、1 update 和结果 42。

```bash
./evaluations/1-libs/sqlite3/run.sh --reference --verbose
```

TLC callback replacement 已关闭。HLR 将 SQLite 内部 static callback table 检测为 FDG，经过审查的 patch 保留这些 host 内部指针。完整 SQLite 上游源码树、CLI、persistence、concurrency 与 regression suite 不属于本定向共享库 workload。预期 audit 为 1 个 translation unit、5 个 CCG class、4 个 FDG class 和 1 个重写文件。
