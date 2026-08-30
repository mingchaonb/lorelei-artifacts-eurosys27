# SDL2_image 2.8.12 validation (TLC + HLR)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the official SDL2_image 2.8.12 shared library and the repository's pinned SDL2 2.28.5 dependency. The workload first creates an `SDL_RWops` over an in-memory two-pixel PNM image. It then loads 14 fixtures shipped in the official SDL2_image release, covering BMP, GIF, CUR, ICO, PCX, PNM, QOI, TGA, XCF, XPM, and SVG paths enabled by this build. Both native and Hecate paths must print one pass record per fixture, finish with `image-load:pass fixtures=14`, and exit zero.

```bash
./evaluations/1-libs/sdl2-image/run.sh --reference --verbose
```

The Hecate lane uses TLC plus HLR for both SDL2 and SDL2_image, with TLC callback replacement disabled. SDL2 uses the dummy-only host configuration. SDL2_image enables its built-in BMP, GIF, LBM, PCX, PNM, QOI, SVG, TGA, XCF, XPM, and XV loaders while disabling external codecs. A reviewed patch leaves its internal static format-detector table at raw host addresses. The official upstream test program is an interactive image viewer rather than an automated pass or fail suite. This recipe reuses its applicable fixtures in a noninteractive regression. LBM and XV remain untested because the release does not ship matching fixtures.

The expected SDL2_image audit is 20 translation units, 1 CCG class, 1 FDG class, and 1 rewritten file.
