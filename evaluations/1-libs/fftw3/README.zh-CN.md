# FFTW 3.3.10 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本配方把固定的官方 release 构建为 AArch64 host 和 x86_64 guest 共享库，生成限于 workload 的 TLC thunk，并在 native 与 Hecate 路径运行相同的定向 public-API workload。port 没有 `hlr` feature，runner 不加载 HLR extension。

## 命令

```bash
./evaluations/1-libs/fftw3/run.sh
./evaluations/1-libs/fftw3/run.sh --install-only
```

devkit 未安装 QEMU 时可设置 `QEMU=/path/to/qemu-x86_64`。

## Workload 与预期结果

workload 分配两个包含 8 个元素的 complex buffer，创建并执行一个正向一维 plan，验证选定输出 bin，再销毁 plan 和 buffer。

两条 lane 成功时均输出 `fftw:1.000,0.000,0.000,-1.000`。该 workload 覆盖 double-precision public planner 与 execution API，不使用上游 bench metadata object。

## 上游测试集

vcpkg port 将当前配置的上游测试 build 安装到 `tools/fftw3/upstream-tests`。默认 `run.sh` 在定向 workload 后，于 native 与 Hecate 两条 lane 执行两个可用 scalar benchmark 检查，两条 lane 均通过 2/2。当前配置关闭 threads、Fortran、float、long-double 和 SIMD variant。不运行纯 QEMU lane。
