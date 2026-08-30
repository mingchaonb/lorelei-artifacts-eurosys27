# libevent 2.1.12-stable validation (TLC + HLR)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds only the `libevent_core` DSO context. Its directed workload activates one no-fd event with `EV_TIMEOUT` and requires exactly one guest callback in native and Hecate paths. TLC callback replacement is disabled. Lock, DNS stress, and the complete upstream suite are outside this claim-scoped workload.

```bash
./evaluations/1-libs/libevent/run.sh --reference --verbose
```

The expected audit is 19 translation units, 1 CCG class, 1 FDG class, and 6 rewritten files.
