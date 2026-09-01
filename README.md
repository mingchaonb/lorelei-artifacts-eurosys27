# EuroSys 2027 Lorelei Artifact

[![EuroSys AE evaluations](https://github.com/mingchaonb/lorelei-artifacts-eurosys27/actions/workflows/evaluations.yml/badge.svg?branch=main)](https://github.com/mingchaonb/lorelei-artifacts-eurosys27/actions/workflows/evaluations.yml)

[中文版](README.zh-CN.md)

This repository is the evaluator-facing build, test, and evidence workspace for the EuroSys 2027 Lorelei submission. Lorelei is the public project name. Hecate is the anonymized name used during paper submission. They refer to the same system.

## 1. Repository layout

```text
eurosys-lorelei-artifacts/
├── docker/
│   └── Dockerfile              Ubuntu 24.04 evaluation image
├── evaluations/
│   ├── 1-libs/                 upstream library tests and native versus Hecate comparisons
│   ├── 2-cli-benchmarks/       the eight command-line workloads in the paper
│   ├── 3-breakdown/            function-call and callback cost breakdowns
│   ├── 4-games/                game playability and frame-rate evaluations
│   ├── 5-modifications/        source-change analysis for Lat, Risotto, and Hecate
│   ├── paper-data/             readable CSV exported from raw results
│   ├── plots/                  paper plots that read only exported CSV
│   ├── install-devkit.sh       install the pinned Lorelei devkit
│   ├── install-tools.sh        install FFmpeg, four DBTs, and separate breakdown tools
│   ├── install-libs.sh         install every library-test package
│   └── install-games.sh        install redistributable game packages
├── vcpkg-overlay/
│   ├── ports/                  vcpkg recipes for evaluated libraries and games
│   ├── ports-tools/            recipes for FFmpeg, four DBTs, and instrumented tools
│   └── triplets/               native AArch64 and guest x86-64 build configurations
├── vcpkg/
│   ├── downloads/              source archive cache shared by every recipe
│   └── installed/              installation root for common tools
└── .work/
    ├── devkit/                 released Lorelei AE devkit
    └── evaluations/            isolated build, package, and install state for each evaluation
```

`vcpkg-overlay/ports/` contains recipes that obtain source from each project's official repository and build, install, and deploy its tests. Every recipe pins an upstream release or commit and verifies the downloaded content. When an upstream build system does not install its tests, the recipe uses a patch under `patches/` or logic in `portfile.cmake` to install the built tests under `tools/<port>/upstream-tests/`. These patches support reproducible builds, test installation, and necessary Hecate adaptation. They do not replace the evaluated library algorithms.

The five numbered directories below `evaluations/` correspond to five groups of paper evidence. Each evaluation keeps its entry point, scope, and results in its own directory. Generated evidence goes to `results/<run-id>/`. `.work/`, vcpkg build trees, and download caches are reusable intermediate state rather than experimental results.

## 2. Prepare the environment

### 2.1 Build the Ubuntu 24.04 ARM64 image

Build the image from the repository root. The Dockerfile installs the system dependencies needed for libraries, DBTs, plotting, and game-package builds. It also creates an unprivileged `user` whose UID and GID match the host account. Section 2.5 separately prepares the GPU driver and sampling tools used when games run on the host:

```bash
docker build \
  --file docker/Dockerfile \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --tag lorelei-eurosys27-ae:ubuntu24.04 \
  docker
```

When building in mainland China, add `--build-arg USE_USTC_MIRROR=1`. This switches the Ubuntu apt sources to USTC and makes the game ports prefer the USTC Ubuntu Ports mirror for AArch64 packages and game data. Its default value is `0`, and evaluators elsewhere do not need to set it:

```bash
docker build \
  --file docker/Dockerfile \
  --build-arg USE_USTC_MIRROR=1 \
  --build-arg USER_UID="$(id -u)" \
  --build-arg USER_GID="$(id -g)" \
  --tag lorelei-eurosys27-ae:ubuntu24.04 \
  docker
```

If network access requires an HTTP proxy:

- Pulling the `ubuntu:24.04` base image uses the Docker daemon's proxy configuration.
- Downloads performed by apt, Git, and other tools inside the Dockerfile use proxy variables passed to `docker build`. Add the explicit options below to the build command. Both cases are passed for compatibility with different tools:

```bash
  --build-arg HTTP_PROXY="$HTTP_PROXY" \
  --build-arg HTTPS_PROXY="$HTTPS_PROXY" \
  --build-arg NO_PROXY="$NO_PROXY" \
  --build-arg http_proxy="$http_proxy" \
  --build-arg https_proxy="$https_proxy" \
  --build-arg no_proxy="$no_proxy" \
```

- If the proxy listens only on the host loopback address, also add `--network host` to the build command or use a host address reachable from the build container.

[`docker/Dockerfile`](docker/Dockerfile) is the source of truth for the dependency list. The command-line workloads use the image's `yt-dlp` to obtain public media input. If the Ubuntu package cannot read current YouTube metadata, install a newer version and select it with `YT_DLP=/absolute/path/to/yt-dlp`.

### 2.2 Start the evaluation container

Start the build and non-graphical evaluation container from the repository root. The artifact repository is mounted read-write, so `.work/`, vcpkg installations, and experiment results produced in the container remain available to the host. Game packages, HLR output, and thunks are also installed in the container, but game processes later run directly on the GUI host. The container therefore does not receive the GPU, X11 socket, or Xauthority:

```bash
export AE_REPO=$PWD

docker run --detach \
  --name lorelei-eurosys27-ae-ubuntu2404 \
  --network host \
  --mount type=bind,src="$AE_REPO",dst=/home/user/eurosys-lorelei-artifacts \
  lorelei-eurosys27-ae:ubuntu24.04 sleep infinity
```

If vcpkg, Git, `yt-dlp`, or other tools inside the container also require the proxy, add the following explicit options to `docker run`. Keep the values after the equals signs so Docker cannot reuse an incorrect or stale proxy setting. Shells started later with `docker exec` inherit these variables:

```bash
  --env HTTP_PROXY="$HTTP_PROXY" \
  --env HTTPS_PROXY="$HTTPS_PROXY" \
  --env NO_PROXY="$NO_PROXY" \
  --env http_proxy="$http_proxy" \
  --env https_proxy="$https_proxy" \
  --env no_proxy="$no_proxy" \
```

Proxy variables are fixed when the container is created. After changing the proxy address on the host, remove and recreate the evaluation container or export the corrected variables again in the current interactive shell.

- The four `install-*.sh` scripts fill the empty case variant when only one of the uppercase or lowercase forms is non-empty. When both forms are configured, each original value is preserved.
- `install-tools.sh`, `install-libs.sh`, and `install-games.sh` automatically retry recognized transient network failures, with at most five attempts per item by default. Set `INSTALL_NETWORK_ATTEMPTS` to change this limit. Build failures, test failures, and user interrupts are not retried.

Use the image's preconfigured unprivileged `user` for builds, libraries, command-line workloads, breakdowns, and data export. Running games is the only host-side evaluation stage, as described in Section 2.5:

```bash
docker exec -it \
  --workdir /home/user/eurosys-lorelei-artifacts \
  lorelei-eurosys27-ae-ubuntu2404 bash
```

### 2.3 Install vcpkg

Clone and bootstrap the pinned vcpkg release at the repository root:

```bash
git clone https://github.com/microsoft/vcpkg.git vcpkg
git -C vcpkg checkout 2026.07.29
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

All ports share `vcpkg/downloads/`, so different libraries do not download the same source archive repeatedly. Evaluations still keep isolated build, package, and install trees below `.work/evaluations/`.

### 2.4 Install evaluation content

Run these four installation scripts from the repository root:

```bash
./evaluations/install-devkit.sh
./evaluations/install-tools.sh
./evaluations/install-libs.sh
./evaluations/install-games.sh
```

- `install-devkit.sh` downloads the architecture-matched EuroSys 2027 AE release, verifies its SHA-256, and installs it under `.work/devkit/`.
- `install-tools.sh` independently installs the QEMU, Box64, and other tool packages used by ordinary performance evaluation and instrumented breakdowns. It does not download or extract the devkit again.
- The remaining scripts reuse installed vcpkg packages, downloads, and build state. They do not clear caches before each invocation.

Installation keeps complete vcpkg output visible and displays progress at the bottom of the terminal. Add `--plain` when redirecting output or when terminal control sequences are undesirable. Every public script resolves paths relative to its own location and can be started from any current directory.

### 2.5 Prepare the GUI host

Game runners must execute directly on the Ubuntu 24.04 ARM64 GUI host. Install the sampling, graphics-inspection, and window-control tools on that host:

```bash
sudo apt update
sudo apt install -y \
  mangohud mesa-utils vulkan-tools \
  libgl-dev libglx-dev libvulkan-dev \
  x11-utils x11-xserver-utils xdotool \
  cmake libdw1 libglib2.0-0
```

`libgl-dev`, `libglx-dev`, and `libvulkan-dev` provide the host headers used to compile the GL and Vulkan preflight probes in the game runners.

The host must also have working OpenGL and Vulkan drivers for its physical GPU. NVIDIA, AMD, and Arm GPUs use the corresponding distribution or vendor driver. `llvmpipe`, `softpipe`, and other software renderers are not valid substitutes. Check the host before running a game:

```bash
glxinfo -B
vulkaninfo --summary
```

Confirm that the `glxinfo -B` renderer names the intended physical GPU and that `vulkaninfo --summary` lists the same device. Game runners inherit `DISPLAY` and `XAUTHORITY` from the current GUI session. No manual override is normally needed when launching them from a desktop terminal.

## 3. Validate the artifact

The commands below read the Lorelei devkit from `.work/devkit/` and use the QEMU, Blink, Box64, and FEX executables installed by `install-tools.sh`. Select another installation with `LORELEI_DEVKIT`, `QEMU`, `BLINK`, `BOX64`, or `FEX` when necessary.

**TL;DR: To follow the shortest end-to-end validation path, go directly to [Section 3.6, Quick walkthrough from the clean Docker image](#36-quick-walkthrough-from-the-clean-docker-image).**

### 3.1 Validate library correctness

Our correctness claim is the following. For every package marked `[ALL TESTS PASSED]`, all upstream tests that are discoverable in the current shared-library configuration, belong to the target public C ABI, and are not explicitly excluded pass against the same upstream version in both the native AArch64 and Hecate x86-64 paths. This claim does not extend to other build configurations, static or private ABI tests, atomics and locks, signals, real devices, fuzzing, sanitizers, or stress tests that do not fit the AE time budget.

The complete installation audit on August 30, 2026 is:

| Audited object | To validate | Passed the complete upstream suite | Ratio |
|---|---:|---:|---:|
| library package | 79 | 54 | 68.35% |
| production shared object | 97 | 63 | 64.95% |

Shared-library counts include real production ELF files in each package and do not count `.so` symlink aliases repeatedly. The synthetic `breakdown-test` prerequisite is not counted as a library package. `glvnd` and `vulkan-loader` use Ubuntu system DSOs and do not copy those DSOs into their vcpkg packages, so they increase the package count but not the packaged shared-object count.

After installing every library, reproduce this table with:

```bash
./evaluations/1-libs/_common/summarize-library-inventory.sh
```

Run the set verified to pass all tests:

```bash
./evaluations/1-libs/run-all.sh --verbose
```

Each recipe runs its upstream tests from the vcpkg installation and compares the native AArch64 path with the x86-64 Hecate path. The default command runs only the 54 packages whose README title contains `[ALL TESTS PASSED]`.

Run every library package with:

```bash
./evaluations/1-libs/run-all.sh --all --verbose
```

The complete set also includes packages with explicit exclusions or directed validation only. Each package README and result summary documents its scope and exclusion reasons.

- Both batch modes continue after failures.
- Repeating the same command skips successful libraries and retries failed or interrupted entries.

See [`evaluations/1-libs/README.md`](evaluations/1-libs/README.md) for the library-package layout, per-library entry points, test classification, and evidence format.

### 3.2 Validate command-line programs

Run the eight command-line workloads:

```bash
./evaluations/2-cli-benchmarks/run-all.sh
```

The runner prepares deterministic compression inputs and public media input, then measures FFTW, zlib, zstd, OpenSSL, and four FFmpeg encoding workloads. Formal runs use five repetitions per lane. Set `REPETITIONS=1` for a quick single-run check. A non-native lane above 20 times native is excluded from Figure 17, and an individual execution is terminated at 100 seconds. Results retain complete commands, input hashes, tool versions, and every raw timing. The batch runner supports recovery and skips successful workloads when invoked again. See [`evaluations/2-cli-benchmarks/README.md`](evaluations/2-cli-benchmarks/README.md) for the complete lane, input, and result definitions.

### 3.3 Validate breakdowns

Run the callback address-origin check and the two-argument and six-argument function-call breakdown:

```bash
./evaluations/3-breakdown/box64-callback-track/run.sh
./evaluations/3-breakdown/hecate-callback-track/run.sh
./evaluations/3-breakdown/breakdown-test/run.sh
python3 evaluations/3-breakdown/coverage-effort/run.py
```

The call breakdown and Box64 callback breakdown use the `breakdown-test` package installed by `install-libs.sh` together with separate instrumented QEMU and Box64 packages from `install-tools.sh`. The Hecate callback boundary experiment uses the installed devkit. These runners do not read adjacent source repositories or rebuild emulators at evaluation time. Adjust the sample count, iteration count, and CPU with `ROUNDS`, `ITERATIONS`, and `CPU`. The three experiment READMEs document the exact measurement points.

See [`evaluations/3-breakdown/README.md`](evaluations/3-breakdown/README.md) for the relationship between the breakdown experiments, their measurement definitions, and their entry points.

### 3.4 Validate games

Complete all four installation scripts inside the container, exit it, and run games on the GUI host prepared in Section 2.5. The runners only reuse installation results in the bind-mounted repository. They do not rerun vcpkg, HLR, or thunk builds on the host. Select `native`, `qemu-hecate`, `box64`, or `box64-hecate` with `--lane`. The positional argument is a watchdog duration in seconds and defaults to 30:

```bash
./evaluations/4-games/supertux/run.sh --lane native 30
./evaluations/4-games/supertux/run.sh --lane qemu-hecate 30
./evaluations/4-games/supertux/run.sh --lane box64 30
./evaluations/4-games/supertux/run.sh --lane box64-hecate 30
```

- The game runner performs host graphics checks for every lane and additional window-system and thunk preflight checks for the two Hecate lanes.
- Native and QEMU-Hecate use MangoHud for frame-rate and frame-time sampling. The two Box64 lanes record presentation timestamps. Raw samples and summaries are stored under the game's `results/<run-id>/`.
- For paper-compatible FPS evidence, enter the selected gameplay scene, remain there for at least 15 seconds, and then close the game. The exporter uses only the ten-second window from 12 seconds before close up to 2 seconds before close.
- A longer watchdog such as `300` leaves enough time for manual scene entry.
- Every game supports `GAME_DIR` as an override for the selected game's installation directory.
- The Hollow Knight runner is under `evaluations/4-games/hollow-knight/`. Its proprietary game files cannot be redistributed with this artifact, so the evaluator must provide a legally obtained copy. For Hollow Knight, `GAME_DIR` must directly contain the `Hollow Knight` executable and `Hollow Knight_Data/`:

```bash
GAME_DIR="/absolute/path/to/Hollow Knight" ./evaluations/4-games/hollow-knight/run.sh 30
```

See [`evaluations/4-games/README.md`](evaluations/4-games/README.md) for each game's installation source, runtime prerequisites, FPS sampling window, and result format.

<!-- The author-maintenance SPARK self-hosted workflow is not part of the evaluator reproduction guide. -->

### 3.5 Export paper data and render plots

Run the coverage and source-change analyses, then export all available evidence to readable, paper-compatible CSV files in one step:

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
./evaluations/5-modifications/run.sh
python3 evaluations/export-paper-data.py
```

The exporter produces:

1. `overall.csv`, containing nine execution paths and normalized time for the eight command-line workloads.
2. `game-fps.csv`, containing FPS mean, minimum, maximum, and population variance for four lanes over each game's `[12s, 2s)` pre-close window, together with sample counts and raw FPS log paths.
3. `function-breakdown.csv` and `callback-track.csv`, containing direct-call and callback breakdowns.
4. `coverage-effort.csv` and `modifications.csv`, containing coverage, handwritten and generated Hecate code size, and system modification counts.
5. `manifest.json`, containing SHA-256 hashes of every consumed evidence file and the export configuration.

The plotting scripts read only generated files under `evaluations/paper-data/`:

```bash
python3 evaluations/plots/plot-overall.py
python3 evaluations/plots/plot-game-fps.py
python3 evaluations/plots/plot-coverage-effort.py
python3 evaluations/plots/plot-function-breakdown.py
python3 evaluations/plots/plot-callback-track.py
```

See [`evaluations/5-modifications/README.md`](evaluations/5-modifications/README.md), [`evaluations/paper-data/README.md`](evaluations/paper-data/README.md), and [`evaluations/plots/README.md`](evaluations/plots/README.md) for source-change analysis, CSV schemas, and plotting entry points.

### 3.6 Quick walkthrough from the clean Docker image

After completing the installation in Section 2, the following sequence covers library correctness, every command-line execution path, all three breakdowns, one manual game scene, source modifications, and final export. The quick check reduces only the repetition count; it does not change workloads, lanes, or validation logic:

```bash
./evaluations/1-libs/run-all.sh --verbose
REPETITIONS=1 ./evaluations/2-cli-benchmarks/run-all.sh
ROUNDS=1 ./evaluations/3-breakdown/box64-callback-track/run.sh
ROUNDS=1 ./evaluations/3-breakdown/hecate-callback-track/run.sh
ROUNDS=1 ./evaluations/3-breakdown/breakdown-test/run.sh
```

Next, leave the container. On the GUI host with its graphics driver and MangoHud installed, select one game and allow a long enough watchdog. Enter the target scene, remain there for at least 15 seconds, then close the game normally:

```bash
./evaluations/4-games/openarena/run.sh --lane qemu-hecate 300
```

After closing the game, enter the container again. Analyze coverage and modifications and export all available evidence in one step:

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
./evaluations/5-modifications/run.sh
python3 evaluations/export-paper-data.py
```

Formal data uses the default five command-line repetitions and the default round counts of each breakdown runner. If the same checkout contains saved batch state from the one-repetition walkthrough, start a new five-repetition batch with `--restart` so the two configurations cannot be mixed:

```bash
REPETITIONS=5 ./evaluations/2-cli-benchmarks/run-all.sh --restart
```

## 4. Results and claims

1. Evaluator-generated evidence is stored under the corresponding recipe's `results/<run-id>/`. New runs create new timestamped directories and do not overwrite prior results.
2. A library README title contains `[ALL TESTS PASSED]` only when every non-excluded upstream test passes in both the native and Hecate paths under the current configuration.
3. Tests that do not represent the Lorelei mechanism claim are explicitly excluded rather than counted as Hecate failures. These include atomics and locks, signals, real-device integration, fuzzing, sanitizers, private ABI tests, and stress tests that do not fit the AE time budget.
4. Library evidence retains native and Hecate raw output, exit status, test classification, source and patch identity, and TLC and HLR configuration line counts. A successful build or thunk generation alone is not correctness evidence.
5. Performance evidence retains every raw measurement, input size and SHA-256, complete command, environment and tool versions, and the method used to derive summaries. Performance conclusions in the paper should be recomputed from this raw evidence.
6. Game evidence retains preflight status, run logs, raw FPS samples, and frame-rate summaries. Proprietary Hollow Knight files are not part of the artifact or its availability claim.

## 5. Reproducibility contract

1. Every public command resolves repository paths from its own script location and can be launched from any current directory.
2. The Lorelei devkit, upstream libraries, tools, and redistributable games are pinned to releases, commits, or archive checksums. Downloads are verified before use.
3. vcpkg owns official upstream source acquisition, versioned patch application, compilation, and test installation. The test stage runs only from installation prefixes and never rebuilds tests temporarily from a source tree.
4. Native AArch64 and Hecate x86-64 use the same upstream version and corresponding build configuration. Library correctness evaluation never runs a pure-QEMU full-emulation lane.
5. Every port shares `vcpkg/downloads/`, while each evaluation keeps isolated build, package, install, and generated mechanism state under `.work/evaluations/`.
6. Installation and batch scripts reuse successful state. Failures and interruptions remain visible. Repeating a command skips successful entries and retries incomplete entries unless the evaluator explicitly requests a restart.
7. `results/` contains removable evidence generated locally by evaluators. Cleanup scripts remove only the result directories they explicitly own and never clear shared vcpkg downloads or package caches.
8. Build trees, installation prefixes, download caches, credentials, proprietary inputs, and other temporary files are not committed to the artifact repository.
