# EuroSys 2027 Lorelei Artifact

[English](README.md)

本仓库是 EuroSys 2027 Lorelei 投稿面向 Artifact Evaluation 评审者的构建、测试与证据工作区。Lorelei 是公开项目名。Hecate 是论文投稿期间使用的匿名名称，两者指同一个系统。

## 1. 目录结构

```text
eurosys-lorelei-artifacts/
├── evaluations/
│   ├── 1-libs/                 library 上游测试与 native、Hecate 对照
│   ├── 2-cli-benchmarks/       论文中的八个命令行 workload
│   ├── 3-breakdown/            函数调用与 callback 开销拆分
│   ├── 4-games/                游戏可用性与帧率评测
│   ├── install-devkit.sh       安装固定版本的 Lorelei devkit
│   ├── install-tools.sh        安装 FFmpeg、四个 DBT 和 Box64 breakdown 工具
│   ├── install-libs.sh         安装全部 library 测试包
│   └── install-games.sh        安装可再分发的游戏包
├── vcpkg-overlay/
│   ├── ports/                  被测 library 和游戏的 vcpkg 编译配方
│   ├── ports-tools/            FFmpeg、四个 DBT 与独立插桩工具的配方
│   └── triplets/               native AArch64 与 guest x86-64 构建配置
├── vcpkg/
│   ├── downloads/              所有配方共享的源码下载缓存
│   └── installed/              公共工具的安装目录
└── .work/
    ├── devkit/                 已发布的 Lorelei AE devkit
    └── evaluations/            各项评测隔离的 build、package 和 install 状态
```

`vcpkg-overlay/ports/` 保存从各项目官方原版仓库获取源码并完成编译、安装和测试部署的配方。配方固定上游 release 或 commit，并校验下载内容。若上游构建系统不安装测试，配方会通过 `patches/` 或 `portfile.cmake` 将已构建测试统一安装到 `tools/<port>/upstream-tests/`。这些 patch 用于复现构建、测试安装和必要的 Hecate 适配，不替换被测 library 的算法实现。

`evaluations/` 下四个编号目录分别对应四类论文证据。每项评测的入口、范围和结果都放在自己的目录中。评审者运行产生的证据写入 `results/<run-id>/`，作者参考结果写入 `reference-results/<run-id>/`。`.work/`、vcpkg build tree 和下载缓存只是可复用的中间状态，不属于实验结果。

## 2. 准备环境

### 2.1 系统与依赖

本 artifact 要求运行在 Ubuntu 24.04 AArch64 主机上。library 和命令行评测不要求图形桌面。游戏评测还需要可用的 X11 会话、OpenGL 或 Vulkan 驱动，以及 MangoHud。

安装构建工具、x86-64 交叉编译器、输入下载工具和游戏测量工具：

```bash
sudo apt update
sudo apt install -y \
  build-essential cmake ninja-build git curl ca-certificates \
  xz-utils zip unzip tar pkg-config python3 python3-venv \
  gcc-x86-64-linux-gnu g++-x86-64-linux-gnu \
  yt-dlp mangohud
```

命令行 workload 使用 `yt-dlp` 获取公开媒体输入。如果 Ubuntu 提供的版本无法读取当前 YouTube 元数据，可安装更新版本并通过 `YT_DLP=/absolute/path/to/yt-dlp` 指定。

### 2.2 安装 vcpkg

在本仓库根目录 clone 并初始化固定版本的 vcpkg：

```bash
git clone https://github.com/microsoft/vcpkg.git vcpkg
git -C vcpkg checkout 2026.07.29
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

所有 port 共享 `vcpkg/downloads/`，因此不同 library 不会重复下载同一份源码。各项评测仍使用 `.work/evaluations/` 下相互隔离的 build、package 和 install 目录。

### 2.3 安装评测内容

从仓库根目录依次运行四个安装脚本：

```bash
./evaluations/install-devkit.sh
./evaluations/install-tools.sh
./evaluations/install-libs.sh
./evaluations/install-games.sh
```

`install-devkit.sh` 根据主机架构下载 EuroSys 2027 AE release 并校验 SHA-256，然后安装到 `.work/devkit/`。`install-tools.sh` 也会检查并复用该 devkit，并安装普通性能评测使用的 Box64 与 callback breakdown 专用的独立插桩 Box64。其余脚本会复用已经安装的 vcpkg package、下载和构建状态，不会在每次执行前清空缓存。

安装过程保留完整的 vcpkg 输出，并在终端底部显示进度。重定向输出或不希望出现终端控制序列时可添加 `--plain`。所有公开脚本都根据自身位置解析路径，可以从任意当前目录启动。

## 3. 验证 Artifact

以下命令默认把 Lorelei devkit 读取自 `.work/devkit/`，并使用 `install-tools.sh` 安装的 QEMU、Blink、Box64 和 FEX。需要使用其他安装时，可分别设置 `LORELEI_DEVKIT`、`QEMU`、`BLINK`、`BOX64` 和 `FEX`。

### 3.1 验证库正确性

这里的正确性承诺是：对每个标记为 `[ALL TESTS PASSED]` 的 package，当前 shared-library 配置能够发现、属于目标公开 C ABI 且未被明确排除的上游测试，均在相同上游版本的 native AArch64 与 Hecate x86-64 两条路径通过。该承诺不扩展到其他构建配置、静态或私有 ABI 测试，以及原子操作与锁、signal、真实设备、fuzz、sanitizer 和不适合 AE 时间预算的压力测试。

2026 年 8 月 30 日的完整安装审计如下。共享库数量只统计各 package 中真实的 production ELF 文件，不重复计算 `.so` 软链接。合成的 `breakdown-test` prerequisite 不作为 library package 计数。`glvnd` 和 `vulkan-loader` 使用 Ubuntu 系统 DSO，不把系统 DSO 复制进自身 vcpkg package，因此计入 package 总数但不增加 package 内的共享库数量。

| 统计对象 | 需要验证 | 完整通过上游测试 | 比例 |
|---|---:|---:|---:|
| library package | 79 | 54 | 68.35% |
| production shared object | 97 | 63 | 64.95% |

安装全部 library 后可用仓库内的 inventory 脚本重新计算该表：

```bash
./evaluations/1-libs/_common/summarize-library-inventory.sh
```

运行已经验证为全部测试通过的 library 集合：

```bash
./evaluations/1-libs/run-all.sh --verbose
```

每个配方从 vcpkg 安装目录运行上游测试，比较 native AArch64 与 x86-64 Hecate 两条路径。上面的默认命令只运行 README 标记为 `[ALL TESTS PASSED]` 的 54 个 package。

运行全部 library package：

```bash
./evaluations/1-libs/run-all.sh --all --verbose
```

完整集合还包含存在明确测试排除项或只提供定向验证的 package。排除原因和支持范围记录在各 package 的 README 与结果摘要中。

- 两种批处理都会在失败后继续。
- 再次执行相同命令会跳过已经成功的 library，并重试失败或中断的项目。

### 3.2 验证命令行程序

运行八个命令行 workload：

```bash
./evaluations/2-cli-benchmarks/run-all.sh
```

runner 会准备确定性压缩输入和公开媒体输入，并依次测量 FFTW、zlib、zstd、OpenSSL，以及四个 FFmpeg 编码 workload。每个 workload 记录至少五次测量、完整命令、输入哈希、工具版本和原始时间。批处理支持断点恢复，再次执行会跳过已经成功的 workload。完整 lane、输入和结果说明见 [`evaluations/2-cli-benchmarks/README.md`](evaluations/2-cli-benchmarks/README.md)。

### 3.3 验证 breakdown

运行 callback 地址来源检查和三整数函数调用拆分：

```bash
./evaluations/3-breakdown/box64-callback-track/run.sh
./evaluations/3-breakdown/breakdown-test/run.sh
```

两个实验都使用 `install-libs.sh` 已安装的 `breakdown-test` 包。callback 实验使用 `install-tools.sh` 安装的独立 Box64 插桩 executable，不读取源码树，也不在运行时重新编译 Box64。采样轮数、迭代次数和 CPU 可分别通过 `ROUNDS`、`ITERATIONS` 和 `CPU` 调整。具体测量点见两个实验各自的 README。

### 3.4 验证游戏

评审者可以从已安装的游戏中任选一个运行。参数是运行秒数，缺省为 30 秒：

```bash
./evaluations/4-games/assaultcube/run.sh 30
./evaluations/4-games/openarena/run.sh 30
./evaluations/4-games/redeclipse/run.sh 30
./evaluations/4-games/supertux/run.sh 30
./evaluations/4-games/supertuxkart/run.sh 30
```

游戏 runner 会先执行图形、窗口系统和 thunk preflight，再通过 Hecate 启动未修改的 x86-64 游戏程序。MangoHud 默认在 host 侧采集帧率和帧时间，并将原始样本与汇总写入该游戏的 `results/<run-id>/`。所有游戏都可以使用 `GAME_DIR` 覆盖当前所选游戏的默认安装目录。Hollow Knight 的 runner 也保留在 `evaluations/4-games/hollow-knight/`，但其专有游戏文件不能随 artifact 分发，评审者需自行提供合法副本。对 Hollow Knight，`GAME_DIR` 应直接包含 `Hollow Knight` 可执行文件和 `Hollow Knight_Data/`：

```bash
GAME_DIR="/absolute/path/to/Hollow Knight" ./evaluations/4-games/hollow-knight/run.sh 30
```

## 4. 结果与声明（Results and claims）

1. 评审者生成的证据保存在对应配方的 `results/<run-id>/`，作者提供的参考证据保存在 `reference-results/<run-id>/`。新运行使用新的时间戳目录，不覆盖已有结果。
2. library README 只有在当前配置中所有未排除的上游测试都通过 native 与 Hecate 两条路径时，标题才标记 `[ALL TESTS PASSED]`。
3. 无法代表 Lorelei 所声明机制的测试会明确排除，而不会计为 Hecate 失败。这些测试包括原子操作与锁、signal、真实设备集成、fuzz、sanitizer、private ABI 测试和不适合 AE 时间预算的压力测试。
4. library 结果至少保留 native 与 Hecate 的原始测试输出、退出状态、测试分类、源码和 patch 身份，以及 TLC、HLR 配置代码行数。仅构建成功或成功生成 thunk 不作为正确性证据。
5. 性能结果保留每次原始测量、输入大小与 SHA-256、完整命令、环境与工具版本，以及从原始样本得到汇总结果的方法。论文中的性能结论应从这些原始数据重新计算。
6. 游戏结果保留 preflight 状态、运行日志、MangoHud 原始采样和帧率汇总。Hollow Knight 的专有文件不属于 artifact，也不纳入可用性声明。

## 5. 可复现契约（Reproducibility contract）

1. 所有公开命令都根据脚本自身位置解析仓库路径，可以从任意当前目录启动。
2. Lorelei devkit、上游 library、工具和可再分发游戏均固定 release、commit 或归档校验和。下载内容在使用前验证。
3. vcpkg 负责获取官方上游源码、应用版本化 patch、编译并安装测试。测试运行阶段只使用安装目录，不从 source tree 临时重新构建测试。
4. native AArch64 与 Hecate x86-64 使用同一份上游版本和对应构建配置。library 正确性验证不运行纯 QEMU full-emulation lane。
5. 所有 port 共享 `vcpkg/downloads/`，但每项评测的 build、package、install 和生成机制状态隔离在 `.work/evaluations/` 下。
6. 安装和批处理脚本复用已经成功的状态。失败或中断保持可见，再次执行会跳过成功项目并重试未完成项目，除非评审者显式要求重新开始。
7. `results/` 是评审者本地生成的可删除证据，`reference-results/` 是作者提供的参考证据。清理脚本只删除各自明确负责的结果目录，不清理共享 vcpkg 下载或 package 缓存。
8. build tree、install prefix、下载缓存、凭据、专有输入和其他临时文件不提交到 artifact 仓库。
