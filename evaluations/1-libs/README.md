# Library evaluations

This group aims to run every upstream test discoverable after each selected library configuration is built. A documented lower-level exclusion is acceptable when a test fundamentally requires unsupported atomics, locks, signals, devices, or a similarly out-of-scope mechanism.

## Per-library contract

Each library directory must provide:

1. A README that identifies the pinned upstream release, mechanism path, configured upstream suite, expected result, and exclusions.
2. A self-contained `run.sh` entry point that reads `LORELEI_DEVKIT`, defaulting to the sibling `../lorelei-ae/build/install` checkout.
3. `--install-only`, `--reference`, and `--verbose` where the mode is applicable.
4. A repository-level vcpkg overlay port that fetches the official release and applies reviewed patches from its own `patches/` directory.
5. Every configured upstream test installed by the port under `tools/<port>/upstream-tests`. If upstream has no test installation rule, the port adds one or applies a minimal patch stored under `vcpkg-overlay/ports/<port>/patches/`.
6. Test execution only from the two installed prefixes. `run.sh` must not rebuild tests from an upstream source tree or a vcpkg buildtree.
7. Symmetric native AArch64 and Hecate results for the same installed test manifest. Pure QEMU and full-emulation lanes are never run.
8. Hecate libraries that use HLR generate TLC metadata with callback replacement disabled.
9. Append-only raw logs, environment identity, configuration LOC, HLR and TLC audit records, and a machine-readable summary.
10. Package-local result and reference-result policies. Generated evidence rules must not be placed in the repository root ignore file.
11. `[ALL TESTS PASSED]` on the first README title line only when every non-excluded configured test has no failure in both lanes.
12. One repository-wide source archive cache at `vcpkg/downloads`. Per-library and per-lane install, buildtree, and package roots remain isolated under `.work/evaluations`.

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
15. `ffmpeg`, implemented as one library recipe and one overlay port containing seven independently rewritten DSO contexts. Its one-command reference run completed all 151 registered tests in both result lanes: 131 passed, 20 matched the documented native configuration baseline, and no Hecate-only failure occurred.

FFmpeg's four encoder performance workloads also belong in `../2-cli-benchmarks/ffmpeg/`. That workload grouping does not replace the upstream FATE validation in `ffmpeg/`.

## Completion rule

A target advances from planned to complete only after its clean one-command run succeeds and its reference directory contains the raw evidence needed to recompute the summary. Historical results under `results/library-tests/` are migration inputs, not substitutes for the new recipe.

## Inventory audit

The shared inventory helper counts real ELF files, not `.so` symlink aliases, from each recipe's own vcpkg package directory. It also derives the all-tests numerator exclusively from the first-line `[ALL TESTS PASSED]` marker:

```bash
./evaluations/1-libs/.common/summarize-library-inventory.sh
```

During the 2026-08-30 non-graphics audit, `glvnd` and `vulkan-loader` were being migrated by a separate evaluation lane and the synthetic `breakdown-test` port was not treated as a library package. The corresponding command and snapshot are:

```bash
./evaluations/1-libs/.common/summarize-library-inventory.sh \
  --exclude glvnd --exclude vulkan-loader
```

1. 77 library packages were present.
2. 54 packages carried the verified all-tests marker: 70.13%.
3. The package directories contained 97 production shared objects.
4. All-tests packages contained 63 of those shared objects: 64.95%.
5. No package directory was missing from the clean-run workspace.

## Sequential batch runner

The batch runner executes the verified all-tests set sequentially. It records controller logs and per-library status under `.work/evaluations/1-libs-batch/verified`. A library failure is recorded without stopping later libraries. Repeating the command skips successful libraries and retries failed, interrupted, or pending libraries:

```bash
./evaluations/1-libs/run-all.sh --verbose
```

Override the repository-relative devkit only when needed:

```bash
LORELEI_DEVKIT=/path/to/devkit ./evaluations/1-libs/run-all.sh --verbose
```

An interactive terminal keeps the three most recently completed results, active recipe, and aggregate progress fixed at the bottom while test output scrolls above them. Redirected output automatically uses plain text. Use `--plain` to disable the terminal display explicitly. Use `--verbose` to forward verbose mode into every per-library runner. Use `--restart` to archive the saved controller state and start the verified set again without deleting append-only per-library results. Use `--all` to select every real library recipe, including recipes with documented exclusions, while still excluding the synthetic `breakdown-test` package.
