# zlib 1.3.2 compression workload

This workload archives the deterministic 64 MiB input with upstream `minizip -9`. The port installs `minizip`, `miniunzip`, and their helper DSO under `tools/zlib/upstream-tests`, so the workload runs only installed artifacts. Python's ZIP reader extracts every output and verifies its SHA-256 after timing.

The x86-64 package uses the GNU cross compiler because Blink's AArch64 JIT does not complete this workload with the devkit Clang build of zlib 1.3.2. The native package also uses GCC, and all Blink measurements retain JIT mode.

```bash
./evaluations/2-cli-benchmarks/zlib/run.sh
./evaluations/2-cli-benchmarks/zlib/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/zlib/run.sh --lanes native,qemu,blink,qemu-hecate
```
