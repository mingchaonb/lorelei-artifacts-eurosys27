# Three-integer function call breakdown

This benchmark measures `int breakdown_test(int first, int second, int third)` from the `breakdown-test` port. The function only returns its first argument. This keeps the host function body near an empty operation while preserving the packing and transfer of three integer arguments.

Install the port from `1-libs`, then run the breakdown:

```bash
../../1-libs/breakdown-test/run.sh --install-only /path/to/lorelei-devkit
./run.sh /path/to/lorelei-devkit
```

The breakdown runner only consumes the vcpkg installation produced by `evaluations/1-libs/breakdown-test`. It does not invoke vcpkg. The default run uses five independent QEMU processes with one million calls in each process. Raw output, environment details, and the median summary are written under `results/<UTC timestamp>/`.
