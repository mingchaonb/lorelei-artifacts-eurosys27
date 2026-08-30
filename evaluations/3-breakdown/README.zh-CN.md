# 机制开销拆分

[English](README.md)

本组提供论文机制开销图对应的定向 microbenchmark，以及 Blink、Box64 和 FEX 接入 Hecate 的功能烟测。这里不测量完整应用性能，也不把插桩 Box64 用于 CLI 或游戏评测。

## 1. 实验范围

| 实验 | 目的 | 默认规模 | 入口 |
|---|---|---|---|
| 三整数函数调用拆分 | 分别测量 GTL、Hecate 中间层、QEMU 和 HTL 的单次调用开销 | 5 个进程，每个进程 1,000,000 次调用 | `breakdown-test/run.sh` |
| Box64 callback 地址来源拆分 | 测量 Box64 识别 guest bridge 对应 native callback 时的各阶段开销 | CPU 0 上 5 个进程，每个进程 1,000,000 次检查 | `box64-callback-track/run.sh` |
| Hecate 模拟器烟测 | 验证 Blink、Box64 和 FEX 的直接调用、host callback round trip 与 guest callback 重入 | 每个模拟器调用 guest callback 1,000 次 | `hecate-emulators/run.sh` |

## 2. 准备依赖

先安装合成测试库和公共工具：

```bash
./evaluations/1-libs/breakdown-test/run.sh --install-only
./evaluations/install-tools.sh
```

安装结果包括：

- `breakdown-test` 的 AArch64 host 库、x86-64 guest 库和头文件。
- 普通 QEMU、Blink、Box64 与 FEX。
- callback 拆分专用的插桩 Box64 package。

普通 Box64 与插桩 Box64 彼此独立。`BOX64` 指向普通性能版本，`BOX64_CALLBACK_TRACK` 只覆盖 callback 拆分实验使用的可执行文件路径。

## 3. 三整数函数调用拆分

运行：

```bash
./evaluations/3-breakdown/breakdown-test/run.sh
```

benchmark 调用：

```c
int breakdown_test(int first, int second, int third);
```

函数只返回第一个参数。runner 重新生成 guest thunk，并在生成代码中加入计时标记，然后分别汇总：

1. `gtl_ns`
   - guest thunk 开销。
2. `hecmid_ns`
   - Hecate runtime 中间路径开销。
3. `qemu_ns`
   - QEMU magic syscall 与插件路径开销。
4. `htl_ns`
   - host thunk 开销。
5. `total_ns`
   - 单次调用的总开销。

默认启动 5 个独立 QEMU 进程，每个进程执行 1,000,000 次。可覆盖：

```bash
ROUNDS=7 ITERATIONS=2000000 \
  ./evaluations/3-breakdown/breakdown-test/run.sh
```

## 4. Box64 callback 地址来源拆分

运行：

```bash
./evaluations/3-breakdown/box64-callback-track/run.sh
```

实验让 host 库返回 native callback，Box64 将它转换成 guest 可见 bridge，再把该 bridge 传回 host。插桩的 `GetNativeOrAlt()` 依次测量：

1. guest ELF 地址检查。
2. host DSO 地址检查。
3. memory protection 与映射检查。
4. GOT pattern 检查。
5. Box64 wrapper signature 检查。

前 4 项每个 sample 执行一次。wrapper signature 检查短于单次计时分辨率，因此每个 sample 内重复 1,000 次，再换算为单次开销。host 库同时验证最终恢复出的 native callback 地址正确。

默认固定到 CPU 0。可覆盖运行参数和插桩工具路径：

```bash
CPU=2 ROUNDS=7 ITERATIONS=2000000 \
BOX64_CALLBACK_TRACK=/absolute/path/to/box64-callback-track \
  ./evaluations/3-breakdown/box64-callback-track/run.sh
```

`BOX64_CALLBACK_TRACK` 是可执行文件路径，不是启用插桩的布尔开关。默认路径由 `install-tools.sh` 安装，通常不需要设置。

## 5. Hecate 模拟器烟测

运行：

```bash
./evaluations/3-breakdown/hecate-emulators/run.sh
```

runner 对 Blink、Box64 和 FEX 分别验证：

- guest 直接调用 host 函数。
- host callback 返回 guest 后再次传回 host。
- guest callback 传给 host 并实际调用 1,000 次。
- callback trampoline、模拟器重入和 magic syscall resume 路径。

调整 callback 次数：

```bash
ITERATIONS=5000 ./evaluations/3-breakdown/hecate-emulators/run.sh
```

可使用 `BLINK`、`BOX64` 和 `FEX` 覆盖普通模拟器路径。该烟测不使用插桩 Box64。

## 6. 结果与证据

每次运行写入：

```text
evaluations/3-breakdown/<experiment>/results/<UTC timestamp>/
```

三整数函数与 callback 拆分保存：

- 每轮 stdout 与 stderr。
- 迭代次数、进程数、CPU 与工具身份。
- 各阶段每次操作的原始数值。
- `summary.csv` 中每轮值与中位数。

模拟器烟测保存：

- 三个模拟器各自的 stdout 与 stderr。
- 工具路径、SHA-256 和 vcpkg package 版本。
- callback 次数和固定的正确性输出。

结果只能从原始输出重新汇总。`.work/evaluations/` 下的生成程序、thunk 和安装 prefix 是可复用状态，不是论文证据。
