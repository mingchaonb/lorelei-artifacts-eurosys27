# 可复现评测

[English](README.md)

`evaluations` 按所支撑的论文声明组织面向评审者的配方。每个配方都包含可复现命令、经过审查的输入、原始证据和机器可读的汇总。

## 评测分组

1. `1-libs` 验证选定的库 API 和边界机制。
2. `2-cli-benchmarks` 测量论文报告的八个命令行 workload。
3. `3-breakdown` 测量单次调用、callback 和各机制的开销。
4. `4-games` 测量游戏性能和可玩性。

## 评测工具

发布版 Lorelei devkit、native FFmpeg 工具和四个固定版本的模拟器 fork 与被测库分开打包。另有一个 Box64 包只包含 callback breakdown 使用的计时插桩。从任意目录运行以下命令即可安装：

```bash
./evaluations/install-tools.sh
```

安装器把对应架构的 AE devkit 下载到 `.work/devkit`，复用 vcpkg 中已有的包，并把模拟器和 FFmpeg 安装到 `vcpkg/installed/arm64-linux/tools/`。也可以单独运行 `evaluations/install-devkit.sh`。模拟器配方位于 `vcpkg-overlay/ports-tools`。`box64-ae` 是不带插桩的性能评测工具，`box64-callback-track-ae` 仅用于 callback breakdown。native FFmpeg 来自 vcpkg 内置 port，不来自 Hecate FFmpeg 库测试配方。

## 目录契约

```text
evaluations/
├── common/                         共享且受版本控制的配方输入
├── 1-libs/<package>/
    ├── README.md                   范围和评审者说明
    ├── README.zh-CN.md             中文说明
    ├── run.sh                      唯一公开入口
    ├── standalone-tests.tsv        选定的上游程序和参数
    ├── tests/                      定向边界测试
    ├── tools/                      包内分析工具
    ├── reference-results/<run-id>/ 作者生成的参考证据
    └── results/<run-id>/           评审者生成的证据
├── 2-cli-benchmarks/
├── 3-breakdown/
└── 4-games/

vcpkg-overlay/
├── ports/<package>/                固定源码和构建策略
└── triplets/                       共享 native 与 guest 目标
```

所有公开配方从 `LORELEI_DEVKIT` 读取 devkit，默认值是仓库内的 `.work/devkit`。运行 `evaluations/install-tools.sh` 后，模拟器默认使用 `vcpkg/installed/arm64-linux/tools/` 下的程序。`QEMU`、`BLINK`、`BOX64` 和 `FEX` 可以覆盖对应路径。库配方可按需要提供 `--reference`、`--install-only` 和 `--verbose`。源码获取、版本校验、编译和安装由仓库级 vcpkg overlay 完成。配方必须使用仓库内的 `vcpkg/vcpkg`。

配方在适用时执行以下阶段：

1. 校验工具和 devkit 布局。
2. 通过共享 overlay 让 vcpkg 构建固定版本的 native 和 guest 包。
3. 构建选定的 host 机制包。SDL 使用由 TLC thunk 和 HLR 重写组成的 Hecate 路径。
4. 从最终 host compilation database 运行 HLR，并应用 HLR port 中经过审查的适配。
5. 关闭 TLC callback replacement，生成 Hecate thunk。
6. 运行文档规定的 native 和 Hecate 路径。
7. 以 native 为基线分类 Hecate 结果，并写入只追加的证据目录。

每个包的公开命令必须能写在一行内。SDL2 是参考实现：

```bash
./evaluations/1-libs/sdl2/run.sh
```

可以显式选择其他 devkit 或模拟器：

```bash
LORELEI_DEVKIT=/path/to/devkit QEMU=/path/to/qemu-x86_64 \
  ./evaluations/1-libs/sdl2/run.sh
```

生成的 build tree 位于 `.work/evaluations/`，不属于证据。每个配方把原始证据保存在自身目录旁，并且不会覆盖以前的运行。
