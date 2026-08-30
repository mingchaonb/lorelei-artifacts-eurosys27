# WavPack 5.9.0 validation (TLC + HLR)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the official WavPack 5.9.0 shared library and installs its configured upstream `wvtest` exerciser under `tools/wavpack/upstream-tests`. It runs `wvtest --exhaustive --short --no-extras` against both the native library and the Hecate path. A pass requires the contiguous sequence from `test 0001` through `test 0164`, an exit status of zero, and the terminal result `all tests pass` in both lanes.

```bash
./evaluations/1-libs/wavpack/run.sh --reference --verbose
```

TLC callback replacement is disabled. HLR rewrites the production shared-library closure. The repository-owned manifest registers the `WavpackBlockOutput` callback ABI as a metadata anchor, and the reviewed patch exports that anchor and the HLR file context. It also leaves host-internal static callbacks at raw host addresses. The thread hook remains enabled because `wvtest` exercises threaded encoding. The `--short` suite excludes long-duration variants, while `--no-extras` excludes optional extra scenarios.

The expected audit is 23 translation units, 6 CCG classes, 3 FDG classes, and 10 rewritten files.
