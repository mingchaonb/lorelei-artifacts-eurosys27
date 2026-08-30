# SDL2_ttf 2.24.0 validation (TLC + HLR audit)

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds official SDL2_ttf 2.24.0 with FreeType and without HarfBuzz. Upstream does not register an automated CMake test suite for this release. The port therefore installs one directed text-size test and a checksum-pinned DejaVu Sans font under `tools/sdl2-ttf/upstream-tests`. It runs that test in native and Hecate lanes and requires identical output.

```bash
./evaluations/1-libs/sdl2-ttf/run.sh --reference --verbose
```

The Hecate lane uses the SDL2 TLC plus HLR dependency path and a TLC thunk for SDL2_ttf. HLR still audits the exact SDL2_ttf shared target with callback replacement disabled. The expected result is one translation unit, zero CCG classes, zero FDG classes, and zero rewritten files. SDL2_ttf therefore remains an audited zero-hit item and is not counted as an HLR-transformed DSO.

Run `./evaluations/1-libs/sdl2-ttf/run.sh` to install both architectures, generate the TLC thunks, and run the directed test. Pass `--install-only` to stop after package installation, HLR audit collection, and thunk generation. This directed workload does not claim an upstream all-tests result, so this README does not carry the all-tests marker.
