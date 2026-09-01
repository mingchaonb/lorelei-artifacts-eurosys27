# FFTW 3.3.10 workload

[中文版](README.zh-CN.md)

The selected problem is an out-of-place forward complex two-dimensional transform of size 3072×3072. The input is a unit impulse. The port installs a focused client at `tools/fftw3/upstream-tests/fftw-ae`, and each timed invocation creates an `FFTW_ESTIMATE` plan and executes it 12 times.

The runner requires the completed client output to report the requested size, repetition count, and checksum of 1. All Blink lanes use the default JIT mode. The runner never selects Blink's interpreter mode.

The installed upstream-test tree still contains the original FFTW `bench`, and QEMU-Hecate can run that original driver. The focused client is used for the symmetric comparison because the original multi-purpose driver is not reliable under the comparator's Blink JIT path. The transform itself succeeds once the unrelated driver behavior is removed. This is a Blink JIT limitation, not a Hecate limitation.

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
