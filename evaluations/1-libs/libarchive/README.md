# libarchive 3.8.9 validation (TLC + HLR)

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the official libarchive 3.8.9 shared library. The directed workload creates a restricted PAX archive in memory, then opens it with `archive_read_open2` and guest-provided open, read, skip, and close callbacks. Both native and Hecate paths must recover `payload.txt`, its 24-byte payload, one open callback, five read callbacks, and one close callback.

```bash
./evaluations/1-libs/libarchive/run.sh --reference --verbose
```

TLC callback replacement is disabled. HLR rewrites the production shared-library closure, while a reviewed patch leaves libarchive's host-internal static callback tables at raw host addresses. Command-line tools, upstream regression tests, crypto backends, XML parsers, external compression libraries, filesystem archive I/O, and formats beyond the in-memory PAX tar workload are outside this directed evaluation.

The expected audit is 123 translation units, 3 CCG classes, 3 FDG classes, and 10 rewritten files.
