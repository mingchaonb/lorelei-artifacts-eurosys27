# FFTW 3.3.10 workload

[中文版](README.zh-CN.md)

The selected problem is an out-of-place forward complex two-dimensional transform of size 3072×3072. The input is a unit impulse. The port installs a focused client at `tools/fftw3/upstream-tests/fftw-ae`, and each timed invocation creates an `FFTW_ESTIMATE` plan and executes it 12 times.

The runner requires the completed client output to report the requested size, repetition count, and checksum of 1. All Blink lanes use the default JIT mode. The runner never selects Blink's interpreter mode.

The installed upstream-test tree still contains the original FFTW `bench`, and QEMU-Hecate can run that original driver. Under Blink's JIT path the original multi-purpose driver does not complete reliably, while the transform itself completes once the driver's other behavior is removed. Every lane therefore times the same focused client, and the original driver stays installed for inspection.

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
