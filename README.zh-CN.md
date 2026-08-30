# EuroSys 2027 Lorelei Artifact

[English](README.md)

本仓库是 EuroSys 2027 Lorelei 投稿面向 Artifact Evaluation 评审者的构建、测试与证据工作区。Lorelei 是公开项目名。Hecate 是论文和部分 runtime 接口使用的匿名名称。除非具体配方另有说明，两者指同一个系统。

## 快速开始

默认配置将各源码仓库并列放置：

```text
rover2024/
├── eurosys-lorelei-artifacts/
├── lorelei-ae/build/install/
└── qemu-ae/build/qemu-x86_64
```

首次使用时初始化仓库内的 vcpkg：

```bash
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

依次运行已经验证的 library 集合：

```bash
./evaluations/1-libs/run-all.sh --verbose
```

批处理遇到失败库后仍会继续。再次执行同一命令会跳过成功配方，并重试失败或中断的配方。`--restart` 会归档 controller 状态并重新开始所选集合。`--all` 除了带有 `[ALL TESTS PASSED]` 标记的配方，还会纳入存在明确排除项的配方。

单独运行一个 library：

```bash
./evaluations/1-libs/sdl2/run.sh --verbose
```

所有公开配方都从 `LORELEI_DEVKIT` 读取 devkit。默认值是相对于本仓库解析的 `../lorelei-ae/build/install`，不再接受 devkit 位置参数。patched emulator 默认是 `../qemu-ae/build/qemu-x86_64`，可通过 `QEMU` 覆盖：

```bash
LORELEI_DEVKIT=/absolute/path/to/devkit \
QEMU=/absolute/path/to/qemu-x86_64 \
  ./evaluations/1-libs/sdl2/run.sh --verbose
```

支持 `--install-only` 的 library 配方可只准备 vcpkg package 和机制文件，不运行测试。`--reference` 仅用于生成作者侧参考证据。

## 仓库布局

1. [`evaluations/1-libs/`](evaluations/1-libs/) 保存安装式上游 library 测试，以及 native 与 Hecate 的正确性对照。
2. [`evaluations/2-cli-benchmarks/`](evaluations/2-cli-benchmarks/) 预留给八个命令行性能 workload。
3. [`evaluations/3-breakdown/`](evaluations/3-breakdown/) 保存调用、callback、emulator 和机制开销拆分。
4. [`evaluations/4-games/`](evaluations/4-games/) 保存游戏 preflight、可玩性和帧率配方。
5. [`vcpkg-overlay/`](vcpkg-overlay/) 保存固定版本的 port、经过审查的 patch、Lorelei metadata，以及 native 和 guest triplet。
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
