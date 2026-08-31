# FFmpeg 7.1.5 validation (TLC + HLR)

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe installs FFmpeg 7.1.5 through one repository overlay port and three architecture-role roots:

1. `native` contains the seven upstream AArch64 shared libraries, `ffmpeg`, `ffprobe`, and its configured FATE tree.
2. `guest` contains the corresponding x86-64 libraries, CLI programs, and FATE tree used by Hecate.
3. `hecate` contains the seven HLR AArch64 host libraries.

Every package installs its configured tests at `tools/ffmpeg/upstream-tests`.

```bash
./evaluations/1-libs/ffmpeg/run.sh --verbose
```

The evaluator sees two result lanes only:

1. Native AArch64 executes the installed native FATE tree against the installed native libraries.
2. Hecate executes the installed x86-64 FATE tree against seven generated TLC thunks and the seven HLR AArch64 libraries.

The port fixes upstream to tag `n7.1.5`, commit `3a0867c2bfda4a4d4309ca1a8cbdc6175e67f587`. During installation, it captures FFmpeg's actual C compilation commands and runs HLR separately for each of these DSO translation-unit closures:

- `libavutil`
- `libswresample`
- `libswscale`
- `libavcodec`
- `libavformat`
- `libavfilter`
- `libavdevice`

Generated source and FileContext files stay in vcpkg's disposable buildtree and are not repository inputs. The installed package retains the seven source lists and TLC and HLR statistics for audit. The checked-in `Symbols.conf` files fix the installed CLI and FATE API surface analyzed by TLC, while `Desc.h` records the callback ABI descriptions.

TLC callback replacement is disabled, so saved callbacks are handled by HLR. The post-HLR patches export `LoreGetFileContext` and keep raw host function pointers in C static descriptors, where a run-time FDG expression is not a constant. They do not disable FDG globally. Dynamic assignments and calls retain their generated FDG guards.

This is the no-samples, deliberately restricted FFmpeg configuration documented by the original reproduction record. Twenty pixfmt FATE entries are expected to fail in the native baseline because the configuration disables the image2 demuxer. Matching Hecate failures are classified as baseline skips. Any Hecate-only failure, incomplete test execution, manifest mismatch, or failure in five repeated `api-threadmessage` checks makes the evaluation fail.

The four MP3, FDK AAC, Vorbis, and x264 command-line workloads remain performance-workload evidence. They are not counted as additional upstream unit tests in this directory.
