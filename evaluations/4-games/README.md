# Game evaluations

This group contains reproducible recipes and evidence for game performance and playability. Library-level GLVND and Vulkan validation belongs under `evaluations/1-libs`.

Each game has the same recipe layout as a library evaluation and is started by its own `run.sh`. `LORELEI_DEVKIT` follows the repository-wide default. The optional `SECONDS` argument sets the watchdog duration.

```bash
./evaluations/4-games/openarena/run.sh 30
./evaluations/4-games/supertuxkart/run.sh 60
HOLLOW_USE_VULKAN=1 ./evaluations/4-games/hollow-knight/run.sh 45
```

The watchdog defaults to 30 seconds. Per-game evidence is written under that game's `results/` directory. Writable home directories are runtime state under `.work/evaluations/games/runtime-home`. Override the location with `RUNTIME_HOME_ROOT` when needed.

Before launching a game, the shared harness builds x86-64 probes from `.common/tests` with the selected Lorelei devkit. Every game runs the XRandR probe and verifies that GL and Vulkan proc-address dispatch work together with the ordered thunk database list. OpenArena additionally runs the SDL 1.2 video probe, while the other games run the SDL2 display probe. Build output, probe logs and exit statuses are recorded with the game evidence, and a failed preflight prevents the game from starting.

MangoHud is enabled by default around the host-side QEMU process, where the AArch64 GL and Vulkan work is executed. The HUD is hidden while 100 ms samples are written under `results/<run-id>/mangohud`. Each completed run also contains `fps-summary.json` with stable FPS and frametime statistics. Set `MANGOHUD_ENABLED=0` to disable collection or append collector options with `MANGOHUD_CONFIG_EXTRA`.

Use `delete-all-results.sh --dry-run` to inspect disposable game result directories before deleting them. `delete-all-reference-results.sh` provides the same guarded operation for reference result directories.
