# SDL 1.2 HLR evaluation

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe pins the Ubuntu 24.04 SDL 1.2 implementation, `sdl12-compat` 1.2.68, rewrites its production source with HLR, generates the OpenArena-facing SDL 1.2 thunk and runs a directed x86-64 guest test under Hecate.

```bash
QEMU=/path/to/patched/qemu-x86_64 \
  ./evaluations/1-libs/sdl1/run.sh
```

The directed test covers dummy video initialization, an SDL 1.2 audio callback arriving on a host-created SDL2 thread and `SDL_LoadObject` plus `SDL_LoadFunction` remaining in the guest address space. Use `--install-only` to prepare the host package and thunk for the graphical game runner without executing QEMU.

Build products are disposable under `.work/evaluations/sdl1`. Evidence is append-only under `evaluations/1-libs/sdl1/results`.
