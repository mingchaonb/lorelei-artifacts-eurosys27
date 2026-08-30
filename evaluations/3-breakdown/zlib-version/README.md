# zlib `zlibVersion()` call breakdown

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This benchmark measures the four intervals of one Hecate direct-syscall call using zlib 1.3.2 `zlibVersion()`. The function takes no arguments and returns the library version string, which keeps host work deliberately small.

The guest thunk emits a tagged `ud2` before packing and immediately before entering the guest runtime. QEMU branch `breakdown-timing` recognizes the markers and reports GTL packing, HecMID trigger, QEMU syscall dispatch, and HTL unpacking time.

Run on the ARM64 evaluation host:

```bash
../../1-libs/zlib/run.sh --install-only
./run.sh
```

The breakdown runner only consumes the zlib package installed by `evaluations/1-libs/zlib`. It does not invoke vcpkg or maintain another zlib installation.

Set `ITERATIONS` and `ROUNDS` to override the defaults of one million calls and five independent QEMU processes. Raw stdout and stderr plus `summary.csv` are written under `results/<UTC timestamp>/`.
