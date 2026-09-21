# Game evaluation

[中文版](README.zh-CN.md)

This group compares the native, QEMU-Hecate, Box64, and Box64-Hecate ARM64 game lanes and collects FPS and frametime on the host. `evaluations/1-libs` validates library-level correctness separately, while this group owns game execution and performance evidence.

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

The four lanes use the container-installed ARM64 package, x86-64 package, QEMU, Box64, and Hecate thunks as appropriate. Box64-Hecate retains Box64's existing SDL and graphics wrappers instead of loading duplicate Hecate graphics thunks for the same libraries. Hollow Knight has no redistributable ARM64 package and therefore has no native lane. `GAME_LANE` may set the default lane.

For a paper FPS measurement, every available lane uses the same resolution and the same scene:

| Game | Scene |
| --- | --- |
| AssaultCube | map `ac_desert`, loaded with `--loadmap`, player idle at the spawn point |
| OpenArena | the scene the game reaches at startup, with no map loaded |
| Red Eclipse | map `auster`, loaded through `-x`, player idle at the spawn point |
| SuperTux | `levels/world1/welcome_antarctica.stl`, Tux idle at the start |
| SuperTuxKart | track `hacienda` with `--race-now`, four karts and three laps, the player's kart held at the start line while the AI karts drive |
| Hollow Knight | entered by hand from the same save, player standing still |

The runners load the first five scenes from the command line, and `GAME_SCENE_MAP` overrides the default map or track. OpenArena loads no map by default because starting a map restarts its renderer, after which MangoHud no longer receives frames on the QEMU lane. Its rate is therefore a startup-scene rate rather than an in-match rate.

1. Choose a watchdog long enough to reach the scene. Hollow Knight needs manual navigation, so allow time for it.
2. Start the run. For Hollow Knight, load the save and stop moving.
3. After the scene is ready, leave the game running there for at least 15 seconds.
4. Close the game normally. The paper export uses the ten-second window from 12 seconds before the final sample up to 2 seconds before it. The last two seconds are omitted so shutdown interaction does not affect the result.

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

## 7. FPS collection

All four lanes collect at the host-side presentation boundary used by the AArch64 driver:

- Native and QEMU-Hecate normally use MangoHud.
- SuperTux creates two OpenGL contexts whose independent swap intervals cannot be combined as one MangoHud FPS stream. Its native and QEMU-Hecate lanes therefore record the SDL presentation boundary with a shared evaluation hook.
- Box64 and Box64-Hecate record SDL or GLX presentation timestamps in the pinned Box64 build. This measurement hook does not change guest instruction execution or library selection.
- Presentation timestamps are aggregated over 100 ms windows into an FPS CSV with the same fields as the MangoHud CSV.
- Raw samples are written into the run directory.
- Produces `fps-summary.json` with stable FPS and frametime statistics.

The paper-data exporter reads the raw CSV rather than copying the collector's whole-run summary. For each game, it uses the `elapsed` timestamps to select `[last sample - 12 seconds, last sample - 2 seconds)`. It discards samples above 10000 FPS as measurement noise, then reports the retained and ignored sample counts and the FPS mean, minimum, maximum, and population variance. The default 100 ms interval normally yields about 100 samples before filtering. Fixed-interval indexing is only a fallback for older logs without `elapsed`. A log shorter than 12 seconds is marked as insufficient instead of silently changing the window.

Export the latest available FPS run for every game and lane with:

```bash
python3 evaluations/export-paper-data.py
```

The readable table is written to `evaluations/paper-data/game-fps.csv`.

Disable collection with:

```bash
MANGOHUD_ENABLED=0 ./evaluations/4-games/openarena/run.sh 30
```

Append MangoHud options for native or QEMU-Hecate with:

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
5. Raw FPS collector samples.
6. `fps-summary.json`.
7. The result and raw-log paths retained by `game-fps.csv`.

Preview and remove evaluator results with:

```bash
./evaluations/4-games/delete-all-results.sh --dry-run
./evaluations/4-games/delete-all-results.sh
```

Cleanup never deletes game packages, shared vcpkg caches, or an evaluator-supplied `GAME_DIR`.
