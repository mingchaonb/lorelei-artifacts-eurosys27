# Game evaluation

[中文版](README.zh-CN.md)

This group validates that Hecate can start real x86-64 games through the graphics, window-system, SDL, GL, and Vulkan paths. It collects FPS and frametime with MangoHud. `evaluations/1-libs` validates library-level correctness separately, while this group owns game execution and performance evidence.

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

Run from the repository root:

```bash
./evaluations/install-games.sh
```

For the first five games, this installs:

- A native AArch64 package.
- A guest x86-64 package.
- Game data in a fixed runtime layout.

There is no separate Hecate game package. Hecate runs the unmodified x86-64 executable from the guest package and uses the AArch64 libraries, GTLs, HTLs, and HLR output installed by `1-libs`. Repeated installation reuses existing vcpkg download, build, and package state.

## 3. Run a game

Each runner accepts one optional positional watchdog duration in seconds. The default is 30 seconds:

```bash
./evaluations/4-games/assaultcube/run.sh
./evaluations/4-games/openarena/run.sh 30
./evaluations/4-games/redeclipse/run.sh 30
./evaluations/4-games/supertux/run.sh 30
./evaluations/4-games/supertuxkart/run.sh 60
```

`GAME_DIR` lets any runner use an evaluator-supplied game directory and skips installation of that game's vcpkg package:

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

## 5. Preflight validation

Before starting a game, the shared runner builds and executes x86-64 probes with the selected devkit. A game starts only after every preflight check passes.

Every game validates:

- The XRandR display path.
- GL proc-address dispatch.
- Vulkan proc-address dispatch.
- The ordered thunk-database list.

OpenArena additionally runs an SDL 1.2 video probe. Other games run an SDL2 display probe. Build output, probe stdout, stderr, and exit status are all saved with the run.

## 6. Graphics environment

By default, the runner reads `DISPLAY` and `XAUTHORITY` from:

```text
$HOME/Desktop/spark-gui-env.txt
```

Select another file with `GUI_ENV`:

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

MangoHud wraps the host-side QEMU process by default because the AArch64 GL and Vulkan drivers execute there. The default configuration:

- Keeps the HUD off screen.
- Records one sample every 100 ms.
- Writes raw MangoHud CSV data into the run directory.
- Produces `fps-summary.json` with stable FPS and frametime statistics.

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
evaluations/4-games/<game>/results/<UTC timestamp>/
```

Evidence includes:

1. Game, guest executable, and package identity.
2. Devkit, QEMU, library, and thunk identity.
3. Preflight build and execution logs.
4. Complete game command and watchdog status.
5. Raw MangoHud samples.
6. `fps-summary.json`.

Preview and remove evaluator results with:

```bash
./evaluations/4-games/delete-all-results.sh --dry-run
./evaluations/4-games/delete-all-results.sh
```

Reference results use a separate script:

```bash
./evaluations/4-games/delete-all-reference-results.sh --dry-run
./evaluations/4-games/delete-all-reference-results.sh
```

Cleanup never deletes game packages, shared vcpkg caches, or an evaluator-supplied `GAME_DIR`.
