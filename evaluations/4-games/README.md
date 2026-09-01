# Game evaluation

[中文版](README.zh-CN.md)

This group compares the native, QEMU-Hecate, Box64, and Box64-Hecate ARM64 game lanes and collects FPS and frametime with MangoHud. `evaluations/1-libs` validates library-level correctness separately, while this group owns game execution and performance evidence.

## 1. Current games

| Game | Version | Acquisition | Default graphics path | Entry point |
|---|---:|---|---|---|
| AssaultCube | 1.3.0.2 | Downloadable by the artifact | OpenGL | `assaultcube/run.sh` |
| OpenArena | 0.8.8 | Downloadable by the artifact | OpenGL with SDL 1.2 | `openarena/run.sh` |
| Red Eclipse | 2.0.0 | Downloadable by the artifact | OpenGL | `redeclipse/run.sh` |
| SuperTux | 0.6.3 | Downloaded or built by the artifact | OpenGL | `supertux/run.sh` |
| SuperTuxKart | 1.4 | Downloadable by the artifact | OpenGL | `supertuxkart/run.sh` |
| Hollow Knight | Evaluator-owned legal copy | Not downloaded or redistributed | OpenGL, with optional Vulkan | `hollow-knight/run.sh` |

[`sources.json`](sources.json) pins the upstream version, archive URL, SHA-256, and guest executable identity for the five redistributable games. Hollow Knight is paid proprietary software, so the artifact supplies only its runner.

## 2. Install redistributable games

Run from the repository root inside the evaluation container:

```bash
./evaluations/install-games.sh
```

For the first five games, this installs:

- A native AArch64 package.
- A guest x86-64 package.
- Game data in a fixed runtime layout.

There is no separate Hecate game package. Hecate runs the unmodified x86-64 executable from the guest package and uses the AArch64 libraries, GTLs, HTLs, and HLR output installed by `1-libs`. Repeated installation reuses existing vcpkg download, build, and package state.

The container is responsible only for download, compilation, and installation. The repository is mounted read-write, so every installation tree under `.work/` remains visible to the host. Game runners never invoke vcpkg or regenerate HLR output and thunks on the host.

## 3. Run a game

Leave the evaluation container and run games from a desktop terminal on the Ubuntu 24.04 ARM64 GUI host. Select one lane with `--lane`. Each runner also accepts an optional positional watchdog duration in seconds. The default lane is `qemu-hecate`, and the default watchdog is 30 seconds:

```bash
./evaluations/4-games/supertux/run.sh --lane native 60
./evaluations/4-games/supertux/run.sh --lane qemu-hecate 60
./evaluations/4-games/supertux/run.sh --lane box64 60
./evaluations/4-games/supertux/run.sh --lane box64-hecate 60
```

The four lanes use the container-installed ARM64 package, x86-64 package, QEMU, Box64, and Hecate thunks as appropriate. Hollow Knight has no redistributable ARM64 package and therefore has no native lane. `GAME_LANE` may set the default lane.

For a paper FPS measurement:

1. Use the same resolution and gameplay scene for every available lane.
2. Choose a watchdog long enough to enter the intended gameplay scene.
3. Start the run and navigate to that scene manually.
4. After the scene is ready, leave the game running there for at least 15 seconds.
5. Close the game normally. The paper export uses the ten-second window from 12 seconds before the final sample up to 2 seconds before it. The last two seconds are omitted so shutdown interaction does not affect the result.

`GAME_DIR` lets any runner use an evaluator-supplied game directory instead of the guest package already installed under `.work/`:

```bash
GAME_DIR=/absolute/path/to/game \
  ./evaluations/4-games/openarena/run.sh 30
```

`GAME_DIR` must directly match the layout expected by that runner. If the guest executable is missing, the script prints the exact resolved path.

## 4. Hollow Knight

The evaluator must provide a legal Linux x86-64 copy. The selected directory must directly contain:

- The `Hollow Knight` executable.
- The `Hollow Knight_Data/` directory.

Run the default OpenGL path:

```bash
GAME_DIR="/absolute/path/to/Hollow Knight" \
  ./evaluations/4-games/hollow-knight/run.sh 45
```

Select Vulkan:

```bash
GAME_DIR="/absolute/path/to/Hollow Knight" \
HOLLOW_USE_VULKAN=1 \
  ./evaluations/4-games/hollow-knight/run.sh 45
```

Rendering backend selection:

- The runner uses OpenGL by default.
- Set `HOLLOW_USE_VULKAN=1` to request Vulkan instead.

## 5. Preflight validation

The shared runner always performs the host OpenGL preflight. QEMU-Hecate and Box64-Hecate also build and execute x86-64 thunk probes with the selected devkit. When a probe fails, the runner prints an error summary and log path in the terminal.

Every game validates:

- Host `glxinfo -B` identifies the renderer. A software renderer produces a warning and permits functional validation to continue, but its FPS is not valid performance evidence.
- The XRandR display path.
- GL proc-address dispatch.
- Vulkan proc-address dispatch.
- The ordered thunk-database list.

OpenArena additionally runs an SDL 1.2 video probe. Other games run an SDL2 display probe. Build output, probe stdout, stderr, and exit status are all saved with the run.

## 6. GUI host

Games do not run in the container. The host requires:

- An Ubuntu 24.04 ARM64 GUI session.
- Working OpenGL and Vulkan drivers that match the physical GPU.
- `mangohud`, `mesa-utils`, and `vulkan-tools`.
- `libgl-dev`, `libglx-dev`, and `libvulkan-dev` for compiling the GL and Vulkan preflight probes.
- `x11-utils`, `x11-xserver-utils`, and `xdotool`.
- `cmake`, `libdw1`, and `libglib2.0-0`.

Install the common tools with the following command. Install the GPU driver separately according to the host hardware:

```bash
sudo apt update
sudo apt install -y \
  mangohud mesa-utils vulkan-tools \
  libgl-dev libglx-dev libvulkan-dev \
  x11-utils x11-xserver-utils xdotool \
  cmake libdw1 libglib2.0-0
```

Before a run, use `glxinfo -B` and `vulkaninfo --summary` to verify the physical GPU. `llvmpipe`, `softpipe`, and other software renderers are not valid game-performance results.

The runner inherits `DISPLAY` and `XAUTHORITY` from the current GUI session. No override is normally needed when launched from a desktop terminal. To select another graphical session, set `GUI_ENV` to a file containing both variables:

```bash
GUI_ENV=/absolute/path/to/gui-env.txt \
  ./evaluations/4-games/supertux/run.sh 30
```

Each game receives a separate writable home under:

```text
.work/evaluations/games/runtime-home/<game>/
```

`RUNTIME_HOME_ROOT` overrides its root.

## 7. MangoHud collection

MangoHud wraps the selected lane's host-side process because the AArch64 GL and Vulkan drivers execute there. The default configuration:

- Keeps the HUD off screen.
- Records one sample every 100 ms.
- Writes raw MangoHud CSV data into the run directory.
- Produces `fps-summary.json` with stable FPS and frametime statistics.

The paper-data exporter reads the raw CSV rather than copying MangoHud's whole-run summary. For each game, it uses MangoHud's `elapsed` timestamps to select `[last sample - 12 seconds, last sample - 2 seconds)`, then reports the sample count and FPS mean, minimum, maximum, and population variance. The default 100 ms interval normally yields about 100 samples. Fixed-interval indexing is only a fallback for older logs without `elapsed`. A log shorter than 12 seconds is marked as insufficient instead of silently changing the window.

Export the latest available MangoHud run for every game and lane with:

```bash
python3 evaluations/export-paper-data.py
```

The readable table is written to `evaluations/paper-data/game-fps.csv`.

Disable collection with:

```bash
MANGOHUD_ENABLED=0 ./evaluations/4-games/openarena/run.sh 30
```

Append MangoHud options with:

```bash
MANGOHUD_CONFIG_EXTRA=output_folder=/absolute/path \
  ./evaluations/4-games/openarena/run.sh 30
```

## 8. Results and evidence

Each run writes:

```text
evaluations/4-games/<game>/results/<UTC timestamp>-<lane>/
```

Evidence includes:

1. Game, lane, executable, and package identity.
2. Devkit, QEMU, Box64, library, and thunk identity.
3. Preflight build and execution logs.
4. Complete game command and watchdog status.
5. Raw MangoHud samples.
6. `fps-summary.json`.
7. The result and raw-log paths retained by `game-fps.csv`.

Preview and remove evaluator results with:

```bash
./evaluations/4-games/delete-all-results.sh --dry-run
./evaluations/4-games/delete-all-results.sh
```

Cleanup never deletes game packages, shared vcpkg caches, or an evaluator-supplied `GAME_DIR`.

<!--
## 9. SPARK self-hosted GitHub Actions

The repository provides [`.github/workflows/evaluations.yml`](../../.github/workflows/evaluations.yml). This workflow is manually triggered and requires an Ubuntu 24.04 ARM64 self-hosted runner carrying the `spark-gpu` label. It executes evaluation groups 1 through 5:

1. Install the devkit, all tools, all library packages, and five redistributable games inside the AE Docker image.
2. Run library correctness, all nine CLI lanes, three breakdowns, and the coverage audit inside the container.
3. Verify that the runner uses a physical OpenGL renderer, then run four lanes for each of the five games in the current X11 session on the SPARK host.
4. Leave each game in the initial scene reached after startup. The default watchdog is 30 seconds.
5. Return to the container to analyze modifications and invoke the unified paper-data exporter.
6. Upload every CSV and the manifest under `evaluations/paper-data/` as a `paper-data` artifact, and upload raw evidence from all five groups as a separate `raw-evidence` artifact.

`game-fps-ci.csv` records `scene=initial` and requires every row to use a physical GPU. If a game or lane lacks valid FPS samples, the workflow fails after preserving and uploading the available evidence. Hollow Knight is omitted because the artifact cannot download or redistribute its proprietary files.

Configure the runner on SPARK as follows:

1. Open **Settings > Actions > Runners > New self-hosted runner** for the repository and select Linux and ARM64.
2. Use the commands shown by GitHub to download and extract the runner. Add the `spark-gpu` label during registration:

```bash
./config.sh \
  --url https://github.com/mingchaonb/lorelei-artifacts-eurosys27 \
  --token '<one-time token generated by GitHub>' \
  --name spark \
  --labels spark-gpu \
  --work _work
```

3. Confirm that `functioner` can run Docker and that MangoHud and the graphics tools from Section 6 are installed on the host.
4. For the first run, start the runner in a terminal within the SPARK graphical desktop. It then inherits the correct `DISPLAY` and `XAUTHORITY` values:

```bash
cd /path/to/actions-runner
./run.sh
```

5. Start the job through **Actions > EuroSys AE 1-5 on SPARK > Run workflow**. The form can adjust CLI repetitions, breakdown rounds, the pinned CPU, and the game watchdog. During the game stage, the five games appear sequentially on the SPARK display. Avoid interacting with the desktop or changing window focus while the measurement is active.

To run the agent as a persistent systemd service, first record the actual values from a graphical desktop terminal in `.env` under the runner directory:

```bash
cd /path/to/actions-runner
printf 'DISPLAY=%s\nXAUTHORITY=%s\n' "$DISPLAY" "$XAUTHORITY" >.env
sudo ./svc.sh install functioner
sudo ./svc.sh start
```

Rewrite `.env` and restart the runner service after the graphical session changes. Proxy variables can be placed in the same runner `.env` file. The workflow forwards lower-case and upper-case proxy variables to the Docker build and container.
-->
