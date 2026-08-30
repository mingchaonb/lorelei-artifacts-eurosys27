# EuroSys 2027 Lorelei Artifact

[中文版](README.zh-CN.md)

This repository is the evaluator-facing build, test, and evidence workspace for the EuroSys 2027 Lorelei submission. Lorelei is the public project name. Hecate is the anonymized name used during paper submission. They refer to the same system.

## 1. Repository layout

```text
eurosys-lorelei-artifacts/
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

The five numbered directories below `evaluations/` correspond to five groups of paper evidence. Each evaluation keeps its entry point, scope, and results in its own directory. Evaluator-generated evidence goes to `results/<run-id>/`, while author-generated reference evidence goes to `reference-results/<run-id>/`. `.work/`, vcpkg build trees, and download caches are reusable intermediate state rather than experimental results.

## 2. Prepare the environment

### 2.1 Start a clean Ubuntu 24.04 ARM64 container

The formal evaluation requires a physical ARM64 host with a working Docker Engine. `--platform linux/arm64` prevents Docker from selecting the wrong image; it must not be used to substitute transparent QEMU emulation on an x86-64 host. Confirm the host architecture, then create the container from the repository root:

```bash
test "$(uname -m)" = aarch64

export AE_REPO=$PWD
export AE_XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
test -f "$AE_XAUTHORITY"

docker run --detach \
  --name lorelei-eurosys27-ae-ubuntu2404 \
  --platform linux/arm64 \
  --network host \
  --device /dev/dri \
  --env HOST_UID="$(id -u)" \
  --env HOST_GID="$(id -g)" \
  --env DISPLAY="${DISPLAY:-:0}" \
  --env XAUTHORITY=/home/user/.Xauthority \
  --mount type=bind,src="$AE_REPO",dst=/home/user \
  --mount type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix \
  --mount type=bind,src="$AE_XAUTHORITY",dst=/home/user/.Xauthority,readonly \
  ubuntu:24.04 sleep infinity
```

The `/dev/dri` device, X11 socket, and Xauthority mounts are needed by game evaluations. They may be omitted when reproducing only library, command-line, and breakdown data. Hosts using the proprietary NVIDIA driver must also expose the GPU through their configured container runtime.

Open a root shell in the container, switch Ubuntu Ports to the USTC mirror, and create an unprivileged `user` whose UID and GID match the host account:

```bash
docker exec -it lorelei-eurosys27-ae-ubuntu2404 bash

sed -Ei \
  's#https?://ports\.ubuntu\.com/ubuntu-ports/?#http://mirrors.ustc.edu.cn/ubuntu-ports/#g' \
  /etc/apt/sources.list.d/ubuntu.sources
apt update
apt install -y sudo
groupadd --gid "$HOST_GID" user
useradd --uid "$HOST_UID" --gid "$HOST_GID" \
  --home-dir /home/user --no-create-home --shell /bin/bash user
printf 'user ALL=(ALL) NOPASSWD:ALL\n' >/etc/sudoers.d/user
chmod 0440 /etc/sudoers.d/user
exit
```

Run all subsequent build, evaluation, and export commands in an unprivileged shell:

```bash
docker exec -it \
  --user user \
  --workdir /home/user \
  --env HOME=/home/user \
  lorelei-eurosys27-ae-ubuntu2404 bash
```

### 2.2 Install system dependencies

Library and command-line evaluations do not require a graphical desktop. Game evaluations additionally require a working host X11 session, OpenGL or Vulkan drivers, and MangoHud in the container. The following is the complete dependency set used to build every port, run all five evaluation groups, and export CSV files from a clean `ubuntu:24.04` image:

```bash
sudo apt update
sudo apt install -y \
  build-essential autoconf automake bear bison cmake flex libtool m4 \
  meson ninja-build nasm yasm pkg-config \
  git curl wget ca-certificates file patch patchelf \
  xz-utils zip unzip tar squashfs-tools \
  python3 python3-venv python3-numpy python3-matplotlib python3-tomli \
  gcc-x86-64-linux-gnu g++-x86-64-linux-gnu \
  clang-20 llvm-20-dev libclang-20-dev \
  libglib2.0-dev libdw-dev libelf-dev libcapstone-dev libfdt-dev \
  libpixman-1-dev libslirp-dev libffi-dev libffcall-dev libssl-dev \
  libvulkan1 libvulkan-dev libgl1 libglx0 libgl-dev libglx-dev libx11-dev \
  yt-dlp mangohud x11-xserver-utils x11-utils xdotool
```

The command-line workloads use `yt-dlp` to obtain public media input. If the Ubuntu package cannot read current YouTube metadata, install a newer version and select it with `YT_DLP=/absolute/path/to/yt-dlp`.

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

`install-devkit.sh` downloads the architecture-matched EuroSys 2027 AE release, verifies its SHA-256, and installs it under `.work/devkit/`. `install-tools.sh` also verifies and reuses this devkit. It installs separate QEMU and Box64 packages for ordinary performance evaluation and instrumented breakdowns. The remaining scripts reuse installed vcpkg packages, downloads, and build state. They do not clear caches before each invocation.

Installation keeps complete vcpkg output visible and displays progress at the bottom of the terminal. Add `--plain` when redirecting output or when terminal control sequences are undesirable. Every public script resolves paths relative to its own location and can be started from any current directory.

Game runners in the container need a two-line file containing `DISPLAY` and `XAUTHORITY`:

```bash
mkdir -p .work
printf 'DISPLAY=%s\nXAUTHORITY=%s\n' \
  "$DISPLAY" "$XAUTHORITY" >.work/gui-env
export GUI_ENV=$PWD/.work/gui-env
```

## 3. Validate the artifact

The commands below read the Lorelei devkit from `.work/devkit/` and use the QEMU, Blink, Box64, and FEX executables installed by `install-tools.sh`. Select another installation with `LORELEI_DEVKIT`, `QEMU`, `BLINK`, `BOX64`, or `FEX` when necessary.

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

### 3.2 Validate command-line programs

Run the eight command-line workloads:

```bash
./evaluations/2-cli-benchmarks/run-all.sh
```

The runner prepares deterministic compression inputs and public media input, then measures FFTW, zlib, zstd, OpenSSL, and four FFmpeg encoding workloads. Formal runs use five repetitions per lane; set `REPETITIONS=1` for a quick single-run check. Every workload has a native median of at least 1.5 seconds. A non-native lane above 20 times native is excluded from Figure 17, and an individual execution is terminated at 100 seconds. Results retain complete commands, input hashes, tool versions, and every raw timing. The batch runner supports recovery and skips successful workloads when invoked again. See [`evaluations/2-cli-benchmarks/README.md`](evaluations/2-cli-benchmarks/README.md) for the complete lane, input, and result definitions.

### 3.3 Validate breakdowns

Run the callback address-origin check and the two-argument and six-argument function-call breakdown:

```bash
./evaluations/3-breakdown/box64-callback-track/run.sh
./evaluations/3-breakdown/hecate-callback-track/run.sh
./evaluations/3-breakdown/breakdown-test/run.sh
python3 evaluations/3-breakdown/coverage-effort/run.py
```

The call breakdown and Box64 callback breakdown use the `breakdown-test` package installed by `install-libs.sh` together with separate instrumented QEMU and Box64 packages from `install-tools.sh`. The Hecate callback boundary experiment uses the installed devkit. These runners do not read adjacent source repositories or rebuild emulators at evaluation time. Adjust the sample count, iteration count, and CPU with `ROUNDS`, `ITERATIONS`, and `CPU`. The three experiment READMEs document the exact measurement points.

### 3.4 Validate games

An evaluator may select any installed game. The argument is a watchdog duration in seconds and defaults to 30:

```bash
./evaluations/4-games/assaultcube/run.sh 30
./evaluations/4-games/openarena/run.sh 30
./evaluations/4-games/redeclipse/run.sh 30
./evaluations/4-games/supertux/run.sh 30
./evaluations/4-games/supertuxkart/run.sh 30
```

The game runner performs graphics, window-system, and thunk preflight checks before starting an unmodified x86-64 game through Hecate. MangoHud collects frame-rate and frame-time samples on the host and stores raw samples and a summary under the game's `results/<run-id>/`. For paper-compatible FPS evidence, enter the selected gameplay scene, remain there for at least 15 seconds, and then close the game. The exporter uses only the ten-second window from 12 seconds before close up to 2 seconds before close. A longer watchdog such as `300` leaves enough time for manual scene entry. Every game supports `GAME_DIR` as an override for the selected game's installation directory. A Hollow Knight runner is also provided under `evaluations/4-games/hollow-knight/`, but its proprietary game files cannot be redistributed with this artifact. The evaluator must provide a legally obtained copy. `GAME_DIR` must directly contain the `Hollow Knight` executable and `Hollow Knight_Data/`:

```bash
GAME_DIR="/absolute/path/to/Hollow Knight" ./evaluations/4-games/hollow-knight/run.sh 30
```

### 3.5 Export paper data and render plots

Run the coverage and source-change analyses, then export all available evidence to readable, paper-compatible CSV files in one step:

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
./evaluations/5-modifications/run.sh
python3 evaluations/export-paper-data.py
```

The exporter produces:

1. `overall.csv`, containing nine execution paths and normalized time for the eight command-line workloads.
2. `game-fps.csv`, containing FPS mean, minimum, maximum, and population variance over each game's `[12s, 2s)` pre-close window, together with sample counts and raw MangoHud paths.
3. `function-breakdown.csv` and `callback-track.csv`, containing direct-call and callback breakdowns.
4. `coverage-effort.csv` and `modifications.csv`, containing coverage, handwritten and generated Hecate code size, and system modification counts.
5. `manifest.json`, containing SHA-256 hashes of every consumed evidence file and the export configuration.

The plotting scripts read only generated files under `evaluations/paper-data/`:

```bash
python3 evaluations/plots/plot-overall.py
python3 evaluations/plots/plot-coverage-effort.py
python3 evaluations/plots/plot-function-breakdown.py
python3 evaluations/plots/plot-callback-track.py
```

The export explicitly excludes Risotto performance, aggregate VA and FP statistics, and library distribution. Games that have not been run manually and all other absent experiment lanes remain marked `missing`; they are never filled with constants from the old paper.

### 3.6 Quick walkthrough from a clean container

After completing the installation in Section 2, the following sequence covers library correctness, every command-line execution path, all three breakdowns, one manual game scene, source modifications, and final export. The quick check reduces only the repetition count; it does not change workloads, lanes, or validation logic:

```bash
./evaluations/1-libs/run-all.sh --verbose
REPETITIONS=1 ./evaluations/2-cli-benchmarks/run-all.sh
ROUNDS=1 ./evaluations/3-breakdown/box64-callback-track/run.sh
ROUNDS=1 ./evaluations/3-breakdown/hecate-callback-track/run.sh
ROUNDS=1 ./evaluations/3-breakdown/breakdown-test/run.sh
```

Next, select one game and allow a long enough watchdog. Enter the target scene, remain there for at least 15 seconds, then close the game normally:

```bash
GUI_ENV=$PWD/.work/gui-env ./evaluations/4-games/openarena/run.sh 300
```

Finally, analyze coverage and modifications and export all available evidence in one step:

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

1. Evaluator-generated evidence is stored under the corresponding recipe's `results/<run-id>/`. Author-provided reference evidence is stored under `reference-results/<run-id>/`. New runs create new timestamped directories and do not overwrite prior results.
2. A library README title contains `[ALL TESTS PASSED]` only when every non-excluded upstream test passes in both the native and Hecate paths under the current configuration.
3. Tests that do not represent the Lorelei mechanism claim are explicitly excluded rather than counted as Hecate failures. These include atomics and locks, signals, real-device integration, fuzzing, sanitizers, private ABI tests, and stress tests that do not fit the AE time budget.
4. Library evidence retains native and Hecate raw output, exit status, test classification, source and patch identity, and TLC and HLR configuration line counts. A successful build or thunk generation alone is not correctness evidence.
5. Performance evidence retains every raw measurement, input size and SHA-256, complete command, environment and tool versions, and the method used to derive summaries. Performance conclusions in the paper should be recomputed from this raw evidence.
6. Game evidence retains preflight status, run logs, raw MangoHud samples, and frame-rate summaries. Proprietary Hollow Knight files are not part of the artifact or its availability claim.

## 5. Reproducibility contract

1. Every public command resolves repository paths from its own script location and can be launched from any current directory.
2. The Lorelei devkit, upstream libraries, tools, and redistributable games are pinned to releases, commits, or archive checksums. Downloads are verified before use.
3. vcpkg owns official upstream source acquisition, versioned patch application, compilation, and test installation. The test stage runs only from installation prefixes and never rebuilds tests temporarily from a source tree.
4. Native AArch64 and Hecate x86-64 use the same upstream version and corresponding build configuration. Library correctness evaluation never runs a pure-QEMU full-emulation lane.
5. Every port shares `vcpkg/downloads/`, while each evaluation keeps isolated build, package, install, and generated mechanism state under `.work/evaluations/`.
6. Installation and batch scripts reuse successful state. Failures and interruptions remain visible. Repeating a command skips successful entries and retries incomplete entries unless the evaluator explicitly requests a restart.
7. `results/` contains removable evidence generated locally by evaluators. `reference-results/` contains reference evidence provided by the authors. Cleanup scripts remove only the result directories they explicitly own and never clear shared vcpkg downloads or package caches.
8. Build trees, installation prefixes, download caches, credentials, proprietary inputs, and other temporary files are not committed to the artifact repository.
