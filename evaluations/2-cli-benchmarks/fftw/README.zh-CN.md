# FFTW 3.3.10 workload

[English](README.md)

选定 problem 是大小为 3072×3072 的 out-of-place 正向复数二维变换，输入是单位脉冲。port 将专用客户端安装到 `tools/fftw3/upstream-tests/fftw-ae`。每次计时调用创建一个 `FFTW_ESTIMATE` plan，并执行 12 次变换。

runner 要求已完成的客户端输出报告指定的尺寸、重复次数和数值为 1 的 checksum。所有 Blink lane 都使用默认 JIT 模式。runner 不会选择 Blink 解释器模式。

已安装的 upstream-test tree 仍包含原始 FFTW `bench`，QEMU-Hecate 能够运行该原始 driver。在 Blink 的 JIT 路径下，原始多用途 driver 不能稳定完成，而去掉 driver 的其余行为后，变换本身可以完成。因此所有 lane 统一计时同一个专用客户端，原始 driver 仍保留在安装目录中供检查。

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
