# EuroSys 2027 Lorelei Artifact

[English](README.md)

本仓库是 EuroSys 2027 Lorelei 投稿面向 Artifact Evaluation 评审者的构建、测试与证据工作区。Lorelei 是公开项目名。Hecate 是论文投稿期间使用的匿名名称，两者指同一个系统。

## 1. 目录结构

```text
eurosys-lorelei-artifacts/
├── docker/
│   └── Dockerfile              Ubuntu 24.04 评测镜像
├── evaluations/
│   ├── 1-libs/                 library 上游测试与 native、Hecate 对照
│   ├── 2-cli-benchmarks/       论文中的八个命令行 workload
│   ├── 3-breakdown/            函数调用与 callback 开销拆分
│   ├── 4-games/                游戏可用性与帧率评测
│   ├── 5-modifications/        Lat、Risotto 与 Hecate 源码修改量
│   ├── paper-data/             从原始结果导出的可读 CSV
│   ├── plots/                  只读取 CSV 的论文绘图脚本
│   ├── install-devkit.sh       安装固定版本的 Lorelei devkit
│   ├── install-tools.sh        安装 FFmpeg、四个 DBT 和独立 breakdown 工具
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

`evaluations/` 下五个编号目录分别对应五类论文证据。每项评测的入口、范围和结果都放在自己的目录中。评审者运行产生的证据写入 `results/<run-id>/`。`.work/`、vcpkg build tree 和下载缓存只是可复用的中间状态，不属于实验结果。

## 2. 准备环境

### 2.1 构建 Ubuntu 24.04 ARM64 镜像

从仓库根目录构建镜像。Dockerfile 会安装 library、DBT、绘图和游戏 package 构建所需的系统依赖，并创建与 host UID、GID 一致的普通用户 `user`。宿主机运行游戏所需的 GPU 驱动和采样工具在第 2.5 节单独准备：

```bash
docker build \
  --file docker/Dockerfile \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --tag lorelei-eurosys27-ae:ubuntu24.04 \
  docker
```

在中国大陆构建时，可以额外传入 `--build-arg USE_USTC_MIRROR=1`。该选项会把 Ubuntu apt 源切换到中科大镜像，并让游戏 port 优先从中科大 Ubuntu Ports 镜像下载 AArch64 package 和游戏数据。默认值为 `0`，其他地区不需要设置：

```bash
docker build \
  --file docker/Dockerfile \
  --build-arg USE_USTC_MIRROR=1 \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --tag lorelei-eurosys27-ae:ubuntu24.04 \
  docker
```

如果网络访问需要 HTTP 代理：

- 拉取 `ubuntu:24.04` 基础镜像使用 Docker daemon 的代理配置。
- Dockerfile 内的 apt、Git 和其他下载使用传给 `docker build` 的代理变量。向上面的构建命令添加以下显式参数。大小写形式同时传入，以兼容不同工具：

```bash
  --build-arg HTTP_PROXY="$HTTP_PROXY" \
  --build-arg HTTPS_PROXY="$HTTPS_PROXY" \
  --build-arg NO_PROXY="$NO_PROXY" \
  --build-arg http_proxy="$http_proxy" \
  --build-arg https_proxy="$https_proxy" \
  --build-arg no_proxy="$no_proxy" \
```

- 如果代理只监听 host 的 loopback 地址，构建命令还需添加 `--network host`，或者把代理地址改为 build container 可以访问的 host 地址。

完整依赖清单以 [`docker/Dockerfile`](docker/Dockerfile) 为准。命令行 workload 使用镜像内的 `yt-dlp` 获取公开媒体输入。如果 Ubuntu 提供的版本无法读取当前 YouTube 元数据，可安装更新版本并通过 `YT_DLP=/absolute/path/to/yt-dlp` 指定。

### 2.2 启动评测容器

从仓库根目录启动构建与非图形评测容器。artifact 仓库以读写方式挂载，因此容器内生成的 `.work/`、vcpkg 安装树和实验结果在退出容器后仍可由宿主机使用。游戏也在容器内完成 package、HLR 和 thunk 安装，但游戏进程稍后直接在 GUI 宿主机运行，因此这里不传 GPU、X11 socket 或 Xauthority：

```bash
export AE_REPO=$PWD

docker run --detach \
  --name lorelei-eurosys27-ae-ubuntu2404 \
  --network host \
  --mount type=bind,src="$AE_REPO",dst=/home/user/eurosys-lorelei-artifacts \
  lorelei-eurosys27-ae:ubuntu24.04 sleep infinity
```

如果容器内的 vcpkg、Git、`yt-dlp` 等工具也需要代理，向 `docker run` 命令添加以下显式选项。不要省略等号右侧的值，否则 Docker 可能沿用错误或过期的代理配置。`docker exec` 启动的后续 shell 会继承这些变量：

```bash
  --env HTTP_PROXY="$HTTP_PROXY" \
  --env HTTPS_PROXY="$HTTPS_PROXY" \
  --env NO_PROXY="$NO_PROXY" \
  --env http_proxy="$http_proxy" \
  --env https_proxy="$https_proxy" \
  --env no_proxy="$no_proxy" \
```

代理变量在创建容器时确定。修改 host 上的代理地址后，需要删除并重新创建评测容器，或者在当前交互 shell 中重新导出这些变量。

- 四个 `install-*.sh` 会在大写或小写形式只有一侧非空时自动补齐另一侧。如果两侧都已设置，则保留各自的原值。
- `install-tools.sh`、`install-libs.sh` 和 `install-games.sh` 对可识别的临时网络错误自动重试，默认每项最多尝试 5 次。可通过 `INSTALL_NETWORK_ATTEMPTS` 调整次数。编译失败、测试失败和用户中断不会触发重试。

随后在镜像预设的普通用户 `user` 下完成构建、library、命令行、breakdown 和数据导出。游戏运行是第 2.5 节说明的唯一宿主机执行阶段：

```bash
docker exec -it \
  --workdir /home/user/eurosys-lorelei-artifacts \
  lorelei-eurosys27-ae-ubuntu2404 bash
```

### 2.3 安装 vcpkg

在本仓库根目录 clone 并初始化固定版本的 vcpkg：

```bash
git clone https://github.com/microsoft/vcpkg.git vcpkg
git -C vcpkg checkout 2026.07.29
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

所有 port 共享 `vcpkg/downloads/`，因此不同 library 不会重复下载同一份源码。各项评测仍使用 `.work/evaluations/` 下相互隔离的 build、package 和 install 目录。

### 2.4 安装评测内容

从仓库根目录依次运行四个安装脚本：

```bash
./evaluations/install-devkit.sh
./evaluations/install-tools.sh
./evaluations/install-libs.sh
./evaluations/install-games.sh
```

- `install-devkit.sh` 根据主机架构下载 EuroSys 2027 AE release，校验 SHA-256，并安装到 `.work/devkit/`。
- `install-tools.sh` 独立安装普通性能评测与 breakdown 使用的 QEMU、Box64 等工具 package，不会再次下载或解压 devkit。
- 其余脚本复用已经安装的 vcpkg package、下载和构建状态，不会在每次执行前清空缓存。

安装过程保留完整的 vcpkg 输出，并在终端底部显示进度。重定向输出或不希望出现终端控制序列时可添加 `--plain`。所有公开脚本都根据自身位置解析路径，可以从任意当前目录启动。

### 2.5 准备 GUI 宿主机

游戏 runner 必须直接在 Ubuntu 24.04 ARM64 GUI 宿主机运行。先在宿主机安装采样、图形探测和窗口控制工具：

```bash
sudo apt update
sudo apt install -y \
  mangohud mesa-utils vulkan-tools \
  libgl-dev libglx-dev libvulkan-dev \
  x11-utils x11-xserver-utils xdotool \
  cmake libdw1 libglib2.0-0
```

`libgl-dev`、`libglx-dev` 和 `libvulkan-dev` 提供游戏 runner 编译 GL 与 Vulkan preflight probe 所需的宿主机头文件。

宿主机还必须安装并启用与物理 GPU 匹配的 OpenGL 和 Vulkan 驱动。NVIDIA、AMD 和 Arm GPU 使用各自的发行版或厂商驱动，不能用 `llvmpipe`、`softpipe` 或其他软件渲染器替代。运行游戏前检查：

```bash
glxinfo -B
vulkaninfo --summary
```

确认 `glxinfo -B` 的 renderer 是预期物理 GPU，并确认 `vulkaninfo --summary` 能列出同一设备。游戏 runner 继承当前 GUI 会话的 `DISPLAY` 和 `XAUTHORITY`。正常从桌面终端启动时通常不需要手动设置。

## 3. 验证 Artifact

以下命令默认把 Lorelei devkit 读取自 `.work/devkit/`，并使用 `install-tools.sh` 安装的 QEMU、Blink、Box64 和 FEX。需要使用其他安装时，可分别设置 `LORELEI_DEVKIT`、`QEMU`、`BLINK`、`BOX64` 和 `FEX`。

**太长不看：如果只想按最短路径完成一次端到端验证，直接跳到 [3.6 从干净 Docker 镜像快速 walkthrough](#36-从干净-docker-镜像快速-walkthrough)。**

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

library package 的目录约定、单库入口、测试分类和证据格式见 [`evaluations/1-libs/README.zh-CN.md`](evaluations/1-libs/README.zh-CN.md)。

### 3.2 验证命令行程序

运行八个命令行 workload：

```bash
./evaluations/2-cli-benchmarks/run-all.sh
```

runner 会准备确定性压缩输入和公开媒体输入，并依次测量 FFTW、zlib、zstd、OpenSSL，以及四个 FFmpeg 编码 workload。正式运行默认对每条 lane 重复五次。可用 `REPETITIONS=1` 做单次快速检查。任一非 native lane 超过 native 的 20 倍会从 Figure 17 排除，单次执行达到 100 秒时会立即终止。结果保留完整命令、输入哈希、工具版本和每次原始时间。批处理支持断点恢复，再次执行会跳过已经成功的 workload。完整 lane、输入和结果说明见 [`evaluations/2-cli-benchmarks/README.zh-CN.md`](evaluations/2-cli-benchmarks/README.zh-CN.md)。

### 3.3 验证 breakdown

运行 callback 地址来源检查和 2 参数、6 参数函数调用拆分：

```bash
./evaluations/3-breakdown/box64-callback-track/run.sh
./evaluations/3-breakdown/hecate-callback-track/run.sh
./evaluations/3-breakdown/breakdown-test/run.sh
python3 evaluations/3-breakdown/coverage-effort/run.py
```

函数调用拆分和 Box64 callback 拆分使用 `install-libs.sh` 已安装的 `breakdown-test` 包，并分别使用 `install-tools.sh` 安装的独立插桩 QEMU 与 Box64。Hecate callback 地址边界实验使用已安装的 devkit。这些 runner 不读取相邻源码仓库，也不在运行时重新编译模拟器。采样轮数、迭代次数和 CPU 可分别通过 `ROUNDS`、`ITERATIONS` 和 `CPU` 调整。具体测量点见三个实验各自的 README。

breakdown 的实验关系、统计口径和各入口说明见 [`evaluations/3-breakdown/README.zh-CN.md`](evaluations/3-breakdown/README.zh-CN.md)。

### 3.4 验证游戏

先在容器中完成四个安装脚本，然后退出容器，在第 2.5 节准备好的 GUI 宿主机中运行游戏。runner 只复用 bind-mounted 仓库中的安装结果，不会在宿主机重新执行 vcpkg、HLR 或 thunk 构建。`--lane` 可选择 `native`、`qemu-hecate`、`box64` 或 `box64-hecate`，位置参数是 watchdog 秒数，缺省为 30 秒：

```bash
./evaluations/4-games/supertux/run.sh --lane native 30
./evaluations/4-games/supertux/run.sh --lane qemu-hecate 30
./evaluations/4-games/supertux/run.sh --lane box64 30
./evaluations/4-games/supertux/run.sh --lane box64-hecate 30
```

- 游戏 runner 对所有 lane 执行宿主图形检查，并对两条 Hecate lane 额外执行窗口系统和 thunk preflight。
- MangoHud 默认在 host 侧采集帧率和帧时间，并将原始样本与汇总写入该游戏的 `results/<run-id>/`。
- 采集论文口径的 FPS 时，进入要测的实际游戏场景，保持至少 15 秒，然后关闭游戏。导出器只采用整段记录关闭前第 12 秒到第 2 秒之间的 10 秒窗口。
- 可以传入较长 watchdog，例如 `300`，给人工进入场景留足时间。
- 所有游戏都可以使用 `GAME_DIR` 覆盖当前所选游戏的默认安装目录。
- Hollow Knight 的 runner 位于 `evaluations/4-games/hollow-knight/`。其专有游戏文件不能随 artifact 分发，评审者需自行提供合法副本。对 Hollow Knight，`GAME_DIR` 应直接包含 `Hollow Knight` 可执行文件和 `Hollow Knight_Data/`：

```bash
GAME_DIR="/absolute/path/to/Hollow Knight" ./evaluations/4-games/hollow-knight/run.sh 30
```

各游戏的安装来源、运行前提、FPS 采样窗口和结果格式见 [`evaluations/4-games/README.zh-CN.md`](evaluations/4-games/README.zh-CN.md)。

<!-- 作者维护用的 SPARK self-hosted GitHub Actions 入口不属于 evaluator 复现文档。 -->

### 3.5 导出论文数据与构图

运行 coverage、源码修改量分析，随后一次性把现有实验证据导出为与论文口径对应的可读 CSV：

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
./evaluations/5-modifications/run.sh
python3 evaluations/export-paper-data.py
```

导出器会生成以下数据：

1. `overall.csv`：八个命令行 workload 的九条执行路径及归一化时间。
2. `game-fps.csv`：每个游戏四条 lane 在关闭前 `[12s, 2s)` 窗口的 FPS 平均值、最小值、最大值和总体方差，并保留样本数与原始 MangoHud 路径。
3. `function-breakdown.csv` 与 `callback-track.csv`：直通调用和 callback breakdown。
4. `coverage-effort.csv` 与 `modifications.csv`：覆盖率、Hecate 人工及生成代码量和各系统修改量。
5. `manifest.json`：所有被读取证据的 SHA-256 及导出配置。

绘图脚本只读取 `evaluations/paper-data/` 中生成的 CSV：

```bash
python3 evaluations/plots/plot-overall.py
python3 evaluations/plots/plot-game-fps.py
python3 evaluations/plots/plot-coverage-effort.py
python3 evaluations/plots/plot-function-breakdown.py
python3 evaluations/plots/plot-callback-track.py
```

修改量统计、CSV schema 和绘图入口分别见 [`evaluations/5-modifications/README.zh-CN.md`](evaluations/5-modifications/README.zh-CN.md)、[`evaluations/paper-data/README.zh-CN.md`](evaluations/paper-data/README.zh-CN.md) 和 [`evaluations/plots/README.zh-CN.md`](evaluations/plots/README.zh-CN.md)。

### 3.6 从干净 Docker 镜像快速 walkthrough

完成第 2 节安装后，下面的顺序覆盖 library 正确性、全部命令行执行路径、三个 breakdown、一个人工游戏场景、修改量和最终导出。快速检查只把重复测量缩为一次，不改变 workload、执行路径或验证逻辑：

```bash
./evaluations/1-libs/run-all.sh --verbose
REPETITIONS=1 ./evaluations/2-cli-benchmarks/run-all.sh
ROUNDS=1 ./evaluations/3-breakdown/box64-callback-track/run.sh
ROUNDS=1 ./evaluations/3-breakdown/hecate-callback-track/run.sh
ROUNDS=1 ./evaluations/3-breakdown/breakdown-test/run.sh
```

随后退出容器，在已准备图形驱动和 MangoHud 的 GUI 宿主机中任选一个游戏，以足够长的 watchdog 启动。进入目标场景后保持至少 15 秒，再正常关闭游戏：

```bash
./evaluations/4-games/openarena/run.sh --lane qemu-hecate 300
```

游戏关闭后重新进入容器，运行 coverage、修改量分析并一次性导出全部现有证据：

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
./evaluations/5-modifications/run.sh
python3 evaluations/export-paper-data.py
```

正式数据把命令行 workload 恢复为默认五次，并使用各 breakdown runner 的默认轮数。如果同一 checkout 已保存单次快速检查的批处理状态，必须用 `--restart` 开始新的五次测量，避免混合两种配置：

```bash
REPETITIONS=5 ./evaluations/2-cli-benchmarks/run-all.sh --restart
```

## 4. 结果与声明（Results and claims）

1. 评审者生成的证据保存在对应配方的 `results/<run-id>/`。新运行使用新的时间戳目录，不覆盖已有结果。
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
7. `results/` 是评审者本地生成的可删除证据。清理脚本只删除各自明确负责的结果目录，不清理共享 vcpkg 下载或 package 缓存。
8. build tree、install prefix、下载缓存、凭据、专有输入和其他临时文件不提交到 artifact 仓库。
