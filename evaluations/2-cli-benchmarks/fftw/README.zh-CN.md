# FFTW 3.3.10 workload

[English](README.md)

选定 problem 是大小为 1024×1024 的 out-of-place 正向复数二维变换，传给上游 `bench` 的表达为 `1024x1024`。其规模足以包含非平凡 planning 和重复变换，同时在纯模拟下保持有界。

AE 机器校准时，native 2048×2048 trial 约需 0.6 秒，QEMU 约需 16.7 秒，但该大尺寸会使 Blink JIT 崩溃。最终的 1024×1024 problem 在 Blink 文档规定的 `-j` interpreter 模式下约 32.5 秒完成。因此 Blink lane 会明确记录 `-j`。

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
./evaluations/2-cli-benchmarks/fftw/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
