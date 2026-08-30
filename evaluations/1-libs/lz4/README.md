# lz4 1.10.0 validation (TLC Only) [ALL TESTS PASSED]

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs lz4 1.10.0 and its upstream test through the pinned vcpkg overlay, generates TLC thunks, then executes the installed test in native and Hecate lanes.

## Commands

```bash
./evaluations/1-libs/lz4/run.sh
./evaluations/1-libs/lz4/run.sh --reference --verbose
./evaluations/1-libs/lz4/run.sh --install-only
```

The source patch adds the upstream `tests/fuzzer.c` target, links it against the shared library, and installs it under `tools/lz4/upstream-tests`. Its CTest registration uses 150 deterministic cycles with seed 12345. The installed test passes in native and Hecate, covering normal, HC, dictionary, streaming, and frame APIs. No source-tree rebuild or pure QEMU lane is used.
