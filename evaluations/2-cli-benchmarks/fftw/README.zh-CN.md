# FFTW 3.3.10 workload

[English](README.md)

选定 problem 是大小为 3072×3072 的 out-of-place 正向复数二维变换，传给上游 `bench` 的表达为 `3072x3072`。所有 Blink lane 都使用默认 JIT 模式。

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
./evaluations/2-cli-benchmarks/fftw/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
