# Library evaluations

This group aims to run every upstream test discoverable after each selected library configuration is built. A documented lower-level exclusion is acceptable when a test fundamentally requires unsupported atomics, locks, signals, devices, or a similarly out-of-scope mechanism.

## Per-library contract

Each library directory must provide:

1. A README that identifies the pinned upstream release, mechanism path, configured upstream suite, expected result, and exclusions.
2. A self-contained `run.sh` entry point with a devkit path as its only positional argument.
3. `--install-only`, `--reference`, and `--verbose` where the mode is applicable.
4. A repository-level vcpkg overlay port that fetches the official release and applies reviewed patches from its own `patches/` directory.
5. Every configured upstream test installed by the port under `tools/<port>/upstream-tests`. If upstream has no test installation rule, the port adds one or applies a minimal patch stored under `vcpkg-overlay/ports/<port>/patches/`.
6. Test execution only from the two installed prefixes. `run.sh` must not rebuild tests from an upstream source tree or a vcpkg buildtree.
7. Symmetric native AArch64 and Hecate results for the same installed test manifest. Pure QEMU and full-emulation lanes are never run.
8. Hecate libraries that use HLR generate TLC metadata with callback replacement disabled.
9. Append-only raw logs, environment identity, configuration LOC, HLR and TLC audit records, and a machine-readable summary.
10. Package-local result and reference-result policies. Generated evidence rules must not be placed in the repository root ignore file.
11. `[ALL TESTS PASSED]` on the first README title line only when every non-excluded configured test has no failure in both lanes.

## Migration order

1. `sdl2`, complete.
2. `expat`, complete and used as the first ordinary-library template.
3. `libpcap`, complete.
4. `libevent`, complete.
5. `libcurl`, complete.
6. `libtommath`, complete.
7. `sqlite3`, complete.
8. `libxml2`, complete.
9. `libuv`, complete.
10. `wavpack`, complete.
11. `libarchive`, complete.
12. `sdl2-image`, complete.
13. `sdl2-mixer`, complete.
14. `sdl2-ttf`, complete as a zero-HLR-hit audit and not counted as an HLR-transformed DSO.

FFmpeg is not split into seven library recipes. Its seven DSO contexts jointly support the paper's command-line workloads and belong in `../2-cli-benchmarks/ffmpeg/`.

## Completion rule

A target advances from planned to complete only after its clean one-command run succeeds and its reference directory contains the raw evidence needed to recompute the summary. Historical results under `results/library-tests/` are migration inputs, not substitutes for the new recipe.
