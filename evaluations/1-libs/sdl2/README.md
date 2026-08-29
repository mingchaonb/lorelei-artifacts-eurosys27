# SDL2 2.28.5 library validation

This recipe is the reference implementation of the library evaluation contract. The repository-level vcpkg overlay pins and builds the official SDL release. The recipe then creates SDL and libc-shim thunks and runs the same selected tests in the native baseline and the Hecate path. Hecate is the anonymous submission name for Lorelei. Its SDL path combines TLC thunk generation with HLR rewriting and runtime extensions.

## Evaluator command

Bootstrap the repository-local `vcpkg/` checkout once as documented in [`../../../vcpkg-overlay/README.md`](../../../vcpkg-overlay/README.md). A full test run requires Lorelei tools, both HLR runtime extensions, the QEMU thread hook, the x86-64 sysroot, and `bin/qemu-x86_64` in the release devkit.

```bash
./evaluations/1-libs/sdl2/run.sh /path/to/lorelei-devkit
```

Add `--verbose` to stream vcpkg, thunk-generation, build, and test output while retaining the same raw log files:

```bash
./evaluations/1-libs/sdl2/run.sh --verbose /path/to/lorelei-devkit
```

To install the HLR-rewritten host SDL, generate the SDL thunk and libc shim, and skip all test compilation and execution, use:

```bash
./evaluations/1-libs/sdl2/run.sh --install-only /path/to/lorelei-devkit
```

Install-only mode does not require QEMU or the QEMU thread hook. It writes the installed paths and `tests_run: false` to `summary.json`. The installed files remain under `.work/evaluations/sdl2/` until the next SDL2 invocation replaces that disposable workspace.

The default command writes evaluator-generated evidence to `results/<run-id>/`. To produce the reference evidence shipped from the authors' machine, use:

```bash
./evaluations/1-libs/sdl2/run.sh --reference /path/to/lorelei-devkit
```

Reference runs are written to `reference-results/<run-id>/`. The option changes only the evidence destination and `meta.json` result kind. Both commands execute the same build and test policy.

For a development tree where patched QEMU has not yet been installed into the devkit:

```bash
QEMU=/path/to/patched/qemu-x86_64 \
  ./evaluations/1-libs/sdl2/run.sh /path/to/lorelei-devkit
```

The disposable build tree is `.work/evaluations/sdl2`. Both evidence directories are append-only.

## Included paths

- The SDL automation harness runs all 301 registered cases once with a fixed seed during artifact construction.
- Twenty-one noninteractive upstream programs exercise platform queries, filesystems, RWops, iconv, dynamic loading, locale, qsort, resampling, dummy audio, threads, timers, key tables, sensors, and automated YUV conversion.
- `TestCallbacks.c` directly checks event filters, event watches, log output, assertion handling, timer callbacks, thread entry callbacks, and allocator FDG calls.
- `TestFDG.c` is a minimal independent check for a host function pointer returned to the guest.

Native and Hecate receive the same SDL dummy audio and video environment. A nonzero Hecate result is classified as a baseline skip when the corresponding native command also fails. Otherwise it remains a Hecate failure.

Each run writes `generated/configuration-loc.json`. This file reports physical, code, comment, and blank lines for `Desc.h`, `Manifest_guest.cpp`, and `Manifest_host.cpp`, plus their SHA-256 identities and aggregate counts. Symbols, patches, tests, and shared harness code are excluded from this per-library configuration metric.

## Excluded paths

- `testatomic`, `testlock`, `testsem`, and `torturethread` are excluded because the artifact does not claim to repair emulated atomic-instruction or contention semantics.
- Interactive windows, device hotplug, physical audio, physical input, haptic devices, OpenGL, and Vulkan programs are excluded because they do not provide deterministic noninteractive evidence for the stated dummy-backend pass-through scope.
- Fuzz, sanitizer, stress, and source-coverage campaigns are not part of this recipe.

SDL has no pure-TLC test path in this recipe. The single Hecate path uses TLC to generate the thunk, disables TLC callback replacement, rewrites the host SDL sources with HLR, and loads the HLR runtime extensions. This keeps callback success attributable to the complete mechanism selected for SDL.
