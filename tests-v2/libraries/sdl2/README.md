# SDL2 2.28.5 library validation

This recipe is the reference implementation of the `tests-v2` library contract. The repository-level vcpkg overlay pins and builds the official SDL release. The recipe then creates SDL and libc-shim thunks and runs the same selected tests in native, pure TLC, and HLR lanes.

## Evaluator command

Bootstrap the repository-local `vcpkg/` checkout once as documented in [`../../../vcpkg-overlay/README.md`](../../../vcpkg-overlay/README.md). The release devkit must contain Lorelei tools, both HLR runtime extensions, the QEMU thread hook, the x86-64 sysroot, and `bin/qemu-x86_64`.

```bash
./tests-v2/libraries/sdl2/run.sh /path/to/lorelei-devkit
```

For a development tree where patched QEMU has not yet been installed into the devkit:

```bash
QEMU=/path/to/patched/qemu-x86_64 \
  ./tests-v2/libraries/sdl2/run.sh /path/to/lorelei-devkit
```

The disposable build tree is `.work/tests-v2/sdl2`. Append-only evidence is written beside this recipe under `tests-v2/libraries/sdl2/results/<run-id>/`.

## Included paths

- The SDL automation harness runs all 301 registered cases once with a fixed seed during artifact construction.
- Twenty-one noninteractive upstream programs exercise platform queries, filesystems, RWops, iconv, dynamic loading, locale, qsort, resampling, dummy audio, threads, timers, key tables, sensors, and automated YUV conversion.
- `TestCallbacks.c` directly checks event filters, event watches, log output, assertion handling, timer callbacks, thread entry callbacks, and allocator FDG calls.
- `TestFDG.c` is a minimal independent check for a host function pointer returned to the guest.

Native, pure TLC, and HLR receive the same SDL dummy audio and video environment. A nonzero transformed-lane result is classified as a baseline skip only when the corresponding native command fails in the same way. Otherwise it remains a failure in that mechanism.

## Excluded paths

- `testatomic`, `testlock`, `testsem`, and `torturethread` are excluded because the artifact does not claim to repair emulated atomic-instruction or contention semantics.
- Interactive windows, device hotplug, physical audio, physical input, haptic devices, OpenGL, and Vulkan programs are excluded because they do not provide deterministic noninteractive evidence for the stated dummy-backend pass-through scope.
- Fuzz, sanitizer, stress, and source-coverage campaigns are not part of this recipe.

The pure TLC lane uses TLC callback replacement and does not load HLR extensions. The HLR lane disables TLC callback replacement and loads the HLR runtime extensions. This separation makes callback evidence attributable to the mechanism under test.
