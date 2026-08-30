# EuroSys 2027 Lorelei Artifact

[中文版](README.zh-CN.md)

This repository is the evaluator-facing build, test, and evidence workspace for the EuroSys 2027 Lorelei submission. Lorelei is the public project name. Hecate is the anonymized name used by the paper and by some runtime interfaces. They refer to the same system unless a recipe says otherwise.

## Quick start

Install the host build tools and the GNU x86-64 cross compiler. The zlib guest package uses the GNU compiler to avoid a data-dependent Blink JIT incompatibility observed with the devkit Clang build.

```bash
sudo apt install -y build-essential cmake ninja-build gcc-x86-64-linux-gnu g++-x86-64-linux-gnu python3
```

The default setup places the source checkouts next to this repository under the evaluator's home directory:

```text
/home/user/
├── eurosys-lorelei-artifacts/
├── lorelei-ae/build/install/
└── qemu-ae/build/qemu-x86_64
```

Clone the pinned vcpkg release into the artifact repository root, then bootstrap it once:

```bash
git clone https://github.com/microsoft/vcpkg.git vcpkg
git -C vcpkg checkout 2026.07.29
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

Run the verified library set sequentially:

```bash
./evaluations/1-libs/run-all.sh --verbose
```

The batch runner continues after a failed library. Running the same command again skips successful recipes and retries failed or interrupted recipes. `--restart` archives the controller state and starts the selected set again. `--all` includes recipes with documented exclusions in addition to those marked `[ALL TESTS PASSED]`.

Run one library directly:

```bash
./evaluations/1-libs/sdl2/run.sh --verbose
```

All public recipes read the devkit from `LORELEI_DEVKIT`, which defaults to `../lorelei-ae/build/install` resolved from this repository. The patched emulator defaults to `../qemu-ae/build/qemu-x86_64` and can be overridden with `QEMU`:

```bash
LORELEI_DEVKIT=/absolute/path/to/devkit \
QEMU=/absolute/path/to/qemu-x86_64 \
  ./evaluations/1-libs/sdl2/run.sh --verbose
```

Use `--install-only` when a supported library recipe should prepare its vcpkg packages and mechanism files without running tests. Use `--reference` only to create author-side reference evidence.

## Repository layout

1. [`evaluations/1-libs/`](evaluations/1-libs/) contains installed upstream library tests and native versus Hecate correctness comparisons.
2. [`evaluations/2-cli-benchmarks/`](evaluations/2-cli-benchmarks/) is reserved for the eight command-line performance workloads.
3. [`evaluations/3-breakdown/`](evaluations/3-breakdown/) contains call, callback, emulator, and mechanism breakdowns.
4. [`evaluations/4-games/`](evaluations/4-games/) contains game preflight, playability, and frame-rate recipes.
5. [`vcpkg-overlay/`](vcpkg-overlay/) contains pinned ports, reviewed patches, Lorelei metadata, and the native and guest triplets.
6. `vcpkg/` is the repository-local package manager and shared source archive cache.
7. `.work/evaluations/` contains reusable package, build, install, and generated mechanism state. It is not evidence.

Each library port installs every configured upstream test under `tools/<port>/upstream-tests`. Its `run.sh` executes that upstream suite only from installed native and guest prefixes. It does not rebuild upstream tests from a source tree after installation. Library evaluation uses two symmetric lanes:

1. native AArch64
2. x86-64 through Hecate, using TLC and HLR where the library requires HLR

The artifact never runs a pure-QEMU full-emulation comparison lane.

## Results and claims

Generated evaluator evidence is stored beside its recipe under `results/<run-id>/`. Author-generated evidence uses `reference-results/<run-id>/`. Result directories contain raw logs, commands, environment identity, source and patch audits, configuration LOC, test classification, and a machine-readable summary where applicable.

A library README starts with `[ALL TESTS PASSED]` only when every configured, non-excluded upstream test passes in both native and Hecate lanes. Exclusions must be explicit. Typical out-of-scope categories include atomics and locks, signals, device integration, fuzzing, sanitizers, private ABI tests, and impractical stress tests. A build success or a thunk count alone is not correctness evidence.

## Reproducibility contract

1. Recipes pin upstream releases or commits and verify downloaded archives.
2. vcpkg owns source acquisition, patching, compilation, and installation.
3. All ports share `vcpkg/downloads`, while per-library build and install roots remain isolated under `.work/evaluations`.
4. Scripts resolve repository files from their own location and can be launched from any current directory.
5. Test failures and interrupted runs remain visible. A replacement run creates a new result directory.
6. Performance experiments retain raw samples, input identity, environment state, and the command used to derive aggregates.
7. Generated build trees, installed prefixes, downloaded archives, credentials, proprietary inputs, and temporary files are not committed.

See [`evaluations/README.md`](evaluations/README.md) for the common recipe contract and each evaluation directory for package-specific scope and commands.
