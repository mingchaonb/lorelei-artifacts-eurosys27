# EuroSys 2027 Lorelei Artifact

[English](README.md)

本仓库是 EuroSys 2027 Lorelei 投稿面向 Artifact Evaluation 评审者的构建、测试与证据工作区。Lorelei 是公开项目名。Hecate 是论文和部分 runtime 接口使用的匿名名称。除非具体配方另有说明，两者指同一个系统。

## 快速开始

先安装主机构建工具和 GNU x86-64 交叉编译器。zlib 的 guest 包使用 GNU 编译器，以避开 devkit Clang 构建在 Blink JIT 下出现的数据相关兼容问题。

```bash
sudo apt install -y build-essential cmake ninja-build gcc-x86-64-linux-gnu g++-x86-64-linux-gnu python3
```

默认配置将所有生成的依赖保存在 artifact 仓库内：

```text
eurosys-lorelei-artifacts/
├── .work/devkit/
└── vcpkg/
```

首次使用时，在 artifact 仓库根目录 clone 固定版本的 vcpkg，再完成初始化：

```bash
git clone https://github.com/microsoft/vcpkg.git vcpkg
git -C vcpkg checkout 2026.07.29
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

随后只需依次运行下面三个安装命令，即可准备完整 artifact。第一个命令下载已发布的 Lorelei devkit 并安装共享工具，后两个命令按依赖顺序安装全部 library 配方和打包后的游戏：

```bash
./evaluations/install-tools.sh
./evaluations/install-libs.sh
./evaluations/install-games.sh
```

这三个脚本是 artifact 的全部安装入口。已有的 devkit 下载、vcpkg package、下载和构建状态都会复用。也可以单独运行 `./evaluations/install-devkit.sh` 安装 devkit。工具和 library 安装脚本在终端底部显示两行进度，同时在上方保留完整 vcpkg 输出。重定向输出或不希望出现终端控制序列时可添加 `--plain`。

依次运行已经验证的 library 集合：

```bash
./evaluations/1-libs/run-all.sh --verbose
```

批处理遇到失败库后仍会继续。再次执行同一命令会跳过成功配方，并重试失败或中断的配方。`--restart` 会归档 controller 状态并重新开始所选集合。`--all` 除了带有 `[ALL TESTS PASSED]` 标记的配方，还会纳入存在明确排除项的配方。

单独运行一个 library：

```bash
./evaluations/1-libs/sdl2/run.sh --verbose
```

所有公开配方都从 `LORELEI_DEVKIT` 读取 devkit，其默认值是相对于本仓库解析的 `.work/devkit`。四个固定版本的模拟器默认使用 `evaluations/install-tools.sh` 安装到 `vcpkg/installed/arm64-linux/tools/` 下的可执行文件，可通过 `QEMU`、`BLINK`、`BOX64` 和 `FEX` 覆盖：

```bash
LORELEI_DEVKIT=/absolute/path/to/devkit \
QEMU=/absolute/path/to/qemu-x86_64 \
BLINK=/absolute/path/to/blink \
BOX64=/absolute/path/to/box64 \
FEX=/absolute/path/to/FEX \
  ./evaluations/1-libs/sdl2/run.sh --verbose
```

支持 `--install-only` 的 library 配方可只准备 vcpkg package 和机制文件，不运行测试。`--reference` 仅用于生成作者侧参考证据。

## 仓库布局

1. [`evaluations/1-libs/`](evaluations/1-libs/) 保存安装式上游 library 测试，以及 native 与 Hecate 的正确性对照。
2. [`evaluations/2-cli-benchmarks/`](evaluations/2-cli-benchmarks/) 预留给八个命令行性能 workload。
3. [`evaluations/3-breakdown/`](evaluations/3-breakdown/) 保存调用、callback、emulator 和机制开销拆分。
4. [`evaluations/4-games/`](evaluations/4-games/) 保存游戏 preflight、可玩性和帧率配方。
5. [`vcpkg-overlay/`](vcpkg-overlay/) 保存 library port、固定版本的 AE 工具 port、经过审查的 patch、Lorelei metadata，以及 native 和 guest triplet。
6. `vcpkg/` 是仓库内的 package manager 和共享源码归档缓存。
7. `.work/evaluations/` 保存可复用的 package、build、install 和生成机制状态，不属于证据。

每个 library port 都把当前配置中的全部上游测试安装到 `tools/<port>/upstream-tests`。`run.sh` 只从安装完成的 native 和 guest prefix 执行该上游测试套件，不在安装后重新从 source tree 构建上游测试。library evaluation 使用两条对称 lane：

1. native AArch64
2. x86-64 通过 Hecate，需使用 HLR 的 library 同时采用 TLC 与 HLR

artifact 永远不运行纯 QEMU full-emulation 对照 lane。

## 结果与声明

评审者生成的证据就近保存在配方的 `results/<run-id>/`。作者生成的证据保存在 `reference-results/<run-id>/`。结果目录按适用情况保存原始日志、命令、环境身份、源码与 patch 审计、配置代码行数、测试分类和机器可读汇总。

只有当前配置中所有未排除的上游测试都在 native 与 Hecate lane 通过时，library README 第一行才会带有 `[ALL TESTS PASSED]`。排除项必须明确记录。常见范围外类别包括原子操作与锁、signal、设备集成、fuzz、sanitizer、private ABI 测试和不适合 AE 的压力测试。仅仅构建成功或生成 thunk 数量不能作为正确性证据。

## 可复现契约

1. 配方固定上游 release 或 commit，并验证下载归档。
2. vcpkg 负责源码获取、patch、编译和安装。
3. 所有 port 共享 `vcpkg/downloads`，每个 library 的 build 和 install root 仍隔离在 `.work/evaluations` 下。
4. 脚本根据自身位置解析仓库文件，可从任意当前目录启动。
5. 测试失败和中断运行保持可见，替代运行创建新的结果目录。
6. 性能实验保留原始样本、输入身份、环境状态和聚合结果推导命令。
7. 生成的 build tree、install prefix、下载归档、凭据、专有输入和临时文件不提交。

公共配方契约见 [`evaluations/README.md`](evaluations/README.md)。每项评测的范围和命令见对应 evaluation 目录。
