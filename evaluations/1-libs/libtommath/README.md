# LibTomMath 1.3.0 validation (TLC + HLR)

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the official LibTomMath 1.3.0 shared library. The directed workload installs a deterministic guest random-source callback with `mp_rand_source`, requires two later `mp_rand` calls to invoke it, and compares the resulting multiplication and hexadecimal conversion across native and Hecate paths.

```bash
./evaluations/1-libs/libtommath/run.sh --verbose
```

TLC callback replacement is disabled. HLR detects the internal static random-source initializer as FDG, but the reviewed patch leaves that internal host pointer raw. CCG handles the persistent callback installed by the guest. The demo program and complete arithmetic regression suite are outside this claim-scoped workload.

The expected audit is 154 translation units, 1 CCG class, 1 FDG class, and 3 rewritten files.
