# FFTW 3.3.10 workload

[中文版](README.zh-CN.md)

The selected problem is an out-of-place forward complex two-dimensional transform of size 3072×3072, expressed to upstream `bench` as `3072x3072`. All Blink lanes use the default JIT mode.

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
./evaluations/2-cli-benchmarks/fftw/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
