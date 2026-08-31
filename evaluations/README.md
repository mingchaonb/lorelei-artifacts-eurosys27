# Evaluation guide

[中文版](README.zh-CN.md)

`evaluations/` is the public entry point for Artifact Evaluation. It organizes reproduction recipes by paper claim and does not expose development plans or migration history.

## 1. Evaluation groups

1. [Library correctness](1-libs/README.md)
   - Validates the public C ABI and boundary mechanisms of 79 library packages.
   - Compares native AArch64 with Hecate x86-64.
   - Does not run a pure QEMU full-emulation lane.
2. [Command-line performance](2-cli-benchmarks/README.md)
   - Reproduces the paper's 8 command-line workloads.
   - Compares native, 4 pure emulators, and 4 Hecate-integrated paths.
3. [Mechanism breakdown](3-breakdown/README.md)
   - Measures individual calls, callback address-origin recognition, and Hecate emulator integration.
4. [Game evaluation](4-games/README.md)
   - Validates the graphics, window-system, thunk, and game-launch paths.
   - Records FPS and frametime with MangoHud.
5. [QEMU modification statistics](5-modifications/README.md)
   - Measures QEMU integration changes for Lat, Risotto, and Hecate.
   - Uses an auditable Box64/KZT build dependency closure for Lat.

Each group README defines its claims, commands, parameters, result format, and exclusions. An item README only describes that specific library, workload, breakdown, or game.

## 2. Prepare the environment

Run these commands from the repository root:

```bash
./evaluations/install-devkit.sh
./evaluations/install-tools.sh
./evaluations/install-libs.sh
./evaluations/install-games.sh
```

The installers have these responsibilities:

1. `install-devkit.sh`
   - Downloads the Lorelei AE devkit for the host architecture.
   - Verifies its SHA-256 and installs it under `.work/devkit/`.
2. `install-tools.sh`
   - Installs the native FFmpeg input-preparation tool.
   - Installs pinned QEMU, Blink, Box64, and FEX packages.
   - Installs the instrumented QEMU for call breakdowns and the instrumented Box64 for callback breakdowns.
3. `install-libs.sh`
   - Invokes each library recipe with `run.sh --install-only`.
   - Continues preparing later libraries after a failure.
4. `install-games.sh`
   - Installs native AArch64 and guest x86-64 packages for redistributable games.
   - Continues preparing later games after a failure.

Installation follows these rules:

- Previously installed packages are not deleted before each run.
- Every port shares the `vcpkg/downloads/` source cache.
- vcpkg reuses successful downloads, builds, and binary package state.
- Complete vcpkg output remains visible above a progress display at the bottom of the terminal.
- Use `--plain` when redirecting output or when terminal control sequences are undesirable.

## 3. Shared tools

`install-tools.sh` provides these default paths:

| Tool | Default path | Purpose |
|---|---|---|
| Lorelei devkit | `.work/devkit/` | TLC, HLR, runtime, cross compiler, and patched QEMU plugin |
| FFmpeg | `vcpkg/installed/arm64-linux/tools/ffmpeg/ffmpeg` | Prepares media input and is never timed |
| QEMU | `vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64` | Pure-emulation and Hecate performance paths |
| Instrumented QEMU | `vcpkg/installed/arm64-linux/tools/qemu-breakdown-ae/qemu-x86_64` | Pass-through call phase breakdown only |
| Blink | `vcpkg/installed/arm64-linux/tools/blink-ae/blink` | Pure-emulation and Hecate performance paths |
| Box64 | `vcpkg/installed/arm64-linux/tools/box64-ae/box64` | Uninstrumented performance paths |
| FEX | `vcpkg/installed/arm64-linux/tools/fex-ae/FEX` | Pure-emulation and Hecate performance paths |
| Instrumented Box64 | `vcpkg/installed/arm64-linux/tools/box64-callback-track-ae/box64-callback-track` | Callback address-origin breakdown only |

The ordinary QEMU and Box64 packages are independent from their instrumented counterparts. Instrumented builds never replace `QEMU` or `BOX64` and do not participate in a performance lane.

## 4. Shared interfaces

Every public script resolves the repository from its own location and can be launched from any working directory.

| Variable | Meaning |
|---|---|
| `LORELEI_DEVKIT` | Overrides the default `.work/devkit` |
| `QEMU` | Overrides the ordinary QEMU executable |
| `QEMU_BREAKDOWN` | Overrides the instrumented QEMU used by the call breakdown without affecting `QEMU` or performance evaluation |
| `BLINK` | Overrides the Blink executable |
| `BOX64` | Overrides the ordinary, uninstrumented Box64 executable |
| `FEX` | Overrides the FEX executable |
| `BOX64_CALLBACK_TRACK` | Overrides the instrumented Box64 executable used by the callback breakdown and does not affect `BOX64` or performance evaluation |
| `GAME_DIR` | Overrides the installation directory for the selected game |
| `REPETITIONS` | Overrides the number of performance workload repetitions |
| `TIMEOUT_SECONDS` | Lowers the timeout for one workload repetition and cannot raise Figure 17's 100-second hard limit |

Batch scripts share these properties:

- One failed item does not prevent later items from running.
- Repeating the same command after interruption skips successful items.
- Failed, interrupted, and pending items are retried.
- `--restart` archives the previous controller state and begins again.
- `--plain` disables the progress display fixed to the bottom of the terminal.

## 5. Layout and evidence

```text
evaluations/
├── common/                         Shared code and tools across groups
├── 1-libs/<package>/              One library recipe
├── 2-cli-benchmarks/<workload>/   One performance workload
├── 3-breakdown/<experiment>/      One mechanism experiment
├── 4-games/<game>/                One game recipe
└── 5-modifications/               QEMU modification source analysis

vcpkg-overlay/
├── ports/<package>/               Source, patches, and build policy for evaluated software
├── ports-tools/<tool>/            Shared tool recipes
└── triplets/                      Native, guest, and Hecate build configurations

.work/evaluations/                 Reusable build, package, and installation state
```

- `results/<run-id>/` stores evidence generated locally by an evaluator.
- Every run creates a new UTC timestamp directory and never overwrites prior evidence.
- `.work/`, vcpkg buildtrees, installation prefixes, download caches, and temporary inputs are not evidence.
- Result cleanup does not remove shared vcpkg downloads or package caches.

Every evaluation records at least:

1. Complete commands and exit status.
2. Tool, source, and patch identity.
3. Execution environment and input identity.
4. Raw output.
5. A machine-readable summary from which the conclusion can be recomputed.

Each group README defines its additional evidence requirements.

## 6. Export paper CSV files

The final exporter reads existing raw evidence. It does not implicitly run benchmarks or the TLC coverage audit. After completing the group runners, explicitly generate the coverage and modification evidence before invoking the unified exporter:

```bash
python3 evaluations/3-breakdown/coverage-effort/run.py
./evaluations/5-modifications/run.sh
python3 evaluations/export-paper-data.py
```

The exporter writes `overall.csv`, `game-fps.csv`, `function-breakdown.csv`, `callback-track.csv`, `coverage-effort.csv`, `modifications.csv`, and an input-hash manifest under `evaluations/paper-data/`.
