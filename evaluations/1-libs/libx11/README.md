# libX11 1.8.7

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned Ubuntu 24.04 libX11 source as native AArch64, x86-64 guest, and HLR-rewritten AArch64 packages. The directed X11 test checks non-variadic keysym and Xrm calls, opens the active X11 display, and exercises resource-name variadic calls for XIM and XIC objects.

Run it with:

```bash
QEMU=/path/to/qemu-x86_64 GUI_ENV=/path/to/spark-gui-env.txt ./run.sh --reference
```

- `--install-only` installs and audits all three packages and generates the TLC thunk without requiring an active X11 session.
- `--reference` stores the run below `reference-results`.
- `--verbose` mirrors vcpkg preparation output while preserving the raw log.

The runtime comparison is native versus Hecate only. It never runs a pure QEMU lane. This is a directed display integration workload rather than the complete upstream suite, so the title intentionally has no `[ALL TESTS PASSED]` marker.
