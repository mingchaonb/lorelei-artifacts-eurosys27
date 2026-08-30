# Library correctness evaluation

[中文版](README.zh-CN.md)

This group validates selected libraries' public C ABI and Lorelei boundary mechanisms. Each recipe builds native AArch64 and x86-64 guest packages from a pinned official upstream version, then compares native and Hecate result paths.

## 1. Correctness claim

For a package whose title contains `[ALL TESTS PASSED]`, this artifact claims:

1. The upstream tests discoverable under the selected shared-library configuration are installed in the vcpkg package.
2. Every test within the target public C ABI and not explicitly excluded is executed.
3. Both native AArch64 and Hecate x86-64 pass against the same upstream version.
4. Tests run only from the installation prefix and are not rebuilt from the source tree during execution.

The claim does not extend to:

- Other undocumented build configurations.
- Static-only or private ABI tests.
- Atomic operations, locks, or contention semantics.
- Signal delivery or signal-handler behavior.
- Real audio, video, input, haptic, or hotplug devices.
- Fuzzing, sanitizers, stress, or source-coverage campaigns.
- Long-running tests outside the AE time budget.

## 2. Current coverage

The complete installation audit on August 30, 2026 is:

| Counted object | Requiring validation | Passing the complete upstream suite | Ratio |
|---|---:|---:|---:|
| Library package | 79 | 54 | 68.35% |
| Production shared object | 97 | 63 | 64.95% |

Counting follows these rules:

- The synthetic `breakdown-test` prerequisite is not a library package.
- Shared-object counts include real production ELF files and do not count `.so` symlinks again.
- `glvnd` and `vulkan-loader` use Ubuntu system DSOs, so they count as packages but add no package-owned DSO.
- The all-tests count is determined only by `[ALL TESTS PASSED]` on the first README line.

Recompute the inventory with:

```bash
./evaluations/1-libs/_common/summarize-library-inventory.sh
```

## 3. Execution paths

Each library produces only two correctness result paths:

1. Native
   - Runs installed AArch64 upstream tests.
   - Links installed native AArch64 shared libraries.
2. Hecate
   - Runs installed x86-64 upstream tests.
   - Calls AArch64 host shared libraries through generated thunks.

Library recipes never run a pure QEMU full-emulation lane.

A Hecate library uses one of two mechanisms:

1. TLC Only
   - TLC generates guest and host thunks.
   - LoreHLR is not run and HLR extensions are not loaded.
   - Callbacks may use TLC-generated replacement.
2. TLC + HLR
   - HLR rewrites the production shared-library closure from the final host compilation database.
   - TLC callback replacement must be disabled.
   - HLR and its runtime extensions handle callbacks, CCG, and FDG.
   - Reviewed post-HLR patches address only build or host-internal pointer adaptation that generated code cannot express.

## 4. Installation

Install every library test package once:

```bash
./evaluations/install-libs.sh
```

This command:

1. Invokes every library's `run.sh --install-only`.
2. Obtains pinned upstream sources through the repository vcpkg overlay.
3. Builds native, guest, and applicable Hecate packages.
4. Installs upstream tests under `tools/<port>/upstream-tests/`.
5. Reuses existing download, build, and package caches.
6. Continues installing later libraries after a failure.

Install one library with:

```bash
./evaluations/1-libs/sdl2/run.sh --install-only
```

## 5. Run all tests

Run the 54 packages already validated as passing their complete upstream suites:

```bash
./evaluations/1-libs/run-all.sh --verbose
```

Run all 79 library packages except the synthetic `breakdown-test`:

```bash
./evaluations/1-libs/run-all.sh --all --verbose
```

Both batch modes follow these rules:

- A library failure does not prevent later libraries from running.
- Controller state is stored under `.work/evaluations/1-libs-batch/`.
- Repeating the same command skips successful items.
- Failed, interrupted, and pending items are retried.
- `--restart` archives old controller state and starts again.
- `--plain` disables the progress display fixed to the bottom of the terminal.
- An interactive terminal shows the three most recent results, the current library, and overall progress.

`--all` includes:

- Packages with explicit upstream-test exclusions.
- Packages that provide only a directed public-API workload.
- Explicit exceptions without a complete upstream-test installation path, such as OpenSSL.

It does not automatically classify those packages as all-tests passing.

## 6. Run one library

Using SDL2 as an example:

```bash
./evaluations/1-libs/sdl2/run.sh
./evaluations/1-libs/sdl2/run.sh --verbose
./evaluations/1-libs/sdl2/run.sh --reference
./evaluations/1-libs/sdl2/run.sh --install-only
```

Common modes are:

- Default: installs required packages, generates mechanism files, and runs native and Hecate tests.
- `--verbose`: streams vcpkg, TLC, HLR, build, and test output while retaining raw logs.
- `--reference`: runs the same procedure but writes author reference results.
- `--install-only`: prepares packages and mechanism files without running tests.

If an option is not applicable to a specific library, that library's README must say so explicitly.

## 7. Per-library recipe contract

Every `<package>/` directory provides:

1. `README.md` and `README.zh-CN.md`
   - Pinned upstream version.
   - TLC Only or TLC + HLR path.
   - Test count and expected result.
   - Explicit exclusions and reasons.
2. `run.sh`
   - The only public entry point for that item.
   - Resolves repository paths from its own location.
   - Uses only the repository-local `vcpkg/vcpkg`.
3. vcpkg overlay port
   - Obtains and verifies an official release or commit.
   - Applies versioned patches from its own `patches/` directory.
   - Installs upstream tests for the selected configuration.
4. Result classification and audit
   - Preserves native and Hecate raw logs.
   - Preserves source, patch, TLC, and HLR identity.
   - Preserves configuration LOC and a machine-readable summary.

## 8. Test classification

Each test is classified as:

1. `pass`
   - Both native and Hecate commands succeed.
2. `baseline skip`
   - The native baseline fails under the same configuration.
   - Hecate produces a matching nonzero result.
3. `fail`
   - Native succeeds while Hecate fails.
   - The Hecate test does not complete.
   - Native and Hecate test manifests differ.
4. `excluded`
   - The README declares the test outside scope before execution.
   - The reason must be a mechanism boundary, configuration boundary, or AE time budget and cannot hide a Hecate-only failure.

Only a package with no failure among all non-excluded tests may add `[ALL TESTS PASSED]` to its README title.

## 9. Results and evidence

Evaluator results are written to:

```text
evaluations/1-libs/<package>/results/<run-id>/
```

Author reference results are written to:

```text
evaluations/1-libs/<package>/reference-results/<run-id>/
```

Every run preserves at least:

1. Complete native and Hecate raw output.
2. Each test command, exit status, and classification.
3. Upstream source, vcpkg port, and patch identity.
4. TLC, HLR, runtime, and emulator identity.
5. Configuration LOC and SHA-256 for `Desc.h`, `Manifest_guest.cpp`, and `Manifest_host.cpp`.
6. A machine-readable summary from which pass, skip, and failure counts can be recomputed.

The following are not library correctness evidence:

- Merely building a library successfully.
- Merely generating a thunk successfully.
- Counting exported symbols, packages, or DSOs alone.
- Temporary build and installation state under `.work/evaluations/`.
