# FFTW 3.3.10 workload

[中文版](README.zh-CN.md)

The selected problem is an out-of-place forward complex two-dimensional transform of size 1024×1024, expressed to upstream `bench` as `1024x1024`. It is large enough to include nontrivial planning and repeated transform work while remaining bounded under pure emulation.

Calibration on the AE machine measured about 0.6 seconds for a native 2048×2048 trial and 16.7 seconds for QEMU, but that larger problem crashed Blink's JIT. The final 1024×1024 problem completes in about 32.5 seconds with Blink's documented `-j` interpreter mode. Blink lanes therefore record `-j` explicitly.

```bash
./evaluations/2-cli-benchmarks/fftw/run.sh
./evaluations/2-cli-benchmarks/fftw/run.sh --reference
REPETITIONS=1 ./evaluations/2-cli-benchmarks/fftw/run.sh --lanes native,qemu,blink,qemu-hecate
```
