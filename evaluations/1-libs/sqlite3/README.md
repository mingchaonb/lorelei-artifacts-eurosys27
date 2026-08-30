# SQLite 3.53.4 validation (TLC + HLR)

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe downloads SQLite's official 3.53.4 amalgamation and builds `sqlite3.c` as the only production translation unit. The directed in-memory workload covers the `sqlite3_exec` row callback, a custom SQL scalar function, and an update hook. Native and Hecate paths must both report one row, one update, and result 42.

```bash
./evaluations/1-libs/sqlite3/run.sh --reference --verbose
```

TLC callback replacement is disabled. HLR detects SQLite's internal static callback tables as FDG, but the reviewed patch leaves those host-internal pointers raw. The full SQLite upstream source tree, CLI, persistence, concurrency, and regression suites are outside this directed shared-library workload.

The expected audit is 1 translation unit, 5 CCG classes, 4 FDG classes, and 1 rewritten file.
