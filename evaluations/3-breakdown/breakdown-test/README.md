# Two-argument and six-argument function call breakdown

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This benchmark measures two-argument and six-argument functions from the `breakdown-test` port. Both functions return only their first argument. This keeps the host body near an empty operation while exposing how argument count affects packing and transfer cost.

Install the port from `1-libs`, then run the breakdown:

```bash
../../1-libs/breakdown-test/run.sh --install-only
./run.sh
```

The runner only consumes the vcpkg installation produced by `evaluations/1-libs/breakdown-test`. It does not invoke vcpkg. Each round performs one million two-argument calls and one million six-argument calls, with five rounds by default. Raw output, environment details, and medians grouped by argument count are written under `results/<UTC timestamp>/`.

Timing requires the separate `qemu-breakdown-ae` installed by `install-tools.sh`. It contains probes that recognize guest timing markers and record the four phases, and is never used for command-line performance evaluation. Override it with `QEMU_BREAKDOWN=/absolute/path/to/qemu-x86_64`.
