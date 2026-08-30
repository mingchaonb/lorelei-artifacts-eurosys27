# FFTW 3.3.10 workload

[中文版](README.zh-CN.md)

The selected problem is an out-of-place forward complex two-dimensional transform of size 3072×3072, expressed to upstream `bench` as `3072x3072`. Five native runs on the AE machine have a median of about 1.57 seconds. The Blink lane explicitly uses its documented `-j` interpreter mode.

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
./evaluations/2-cli-benchmarks/fftw/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
