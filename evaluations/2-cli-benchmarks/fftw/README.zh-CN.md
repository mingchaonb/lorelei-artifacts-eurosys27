# FFTW 3.3.10 workload

[English](README.md)

选定 problem 是大小为 3072×3072 的 out-of-place 正向复数二维变换，传给上游 `bench` 的表达为 `3072x3072`。AE 机器上的 native 五次运行中位数约为 1.57 秒。Blink lane 明确使用其文档规定的 `-j` interpreter 模式。

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
./evaluations/2-cli-benchmarks/fftw/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
