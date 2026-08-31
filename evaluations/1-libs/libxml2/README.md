# libxml2 2.15.3 validation (TLC + HLR)

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the official libxml2 2.15.3 shared library. The directed workload feeds an XML document to the push parser in two chunks and requires two start-element callbacks, two end-element callbacks, and seven bytes of character data in both native and Hecate paths.

```bash
./evaluations/1-libs/libxml2/run.sh --verbose
```

TLC callback replacement is disabled. HLR detects internal SAX and parser callback tables as FDG, but the reviewed patch retains their raw host pointers. Python, programs, optional compression, external documents, and the complete upstream test suite are outside this directed shared-library workload.

The expected audit is 37 translation units, 23 CCG classes, 20 FDG classes, and 33 rewritten files.
