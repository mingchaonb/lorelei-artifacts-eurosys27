# Box64 callback address-origin breakdown

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This benchmark measures the address-origin checks in Box64 `GetNativeOrAlt()`. It uses the synthetic `breakdown-test` library installed by `evaluations/1-libs/breakdown-test`.

The host library returns a native three-integer callback. The Box64 wrapper converts it to a guest-visible bridge. The benchmark then passes that bridge back through another wrapped function. Box64 must reject the address as a guest ELF address, reject it as a host DSO address, confirm that it is mapped, reject the GOT pattern, and recognize the Box64 wrapper signature. The host library verifies that Box64 recovered the original native callback address.

The first four checks execute once per sample. The final wrapper-signature comparison is repeated 1000 times inside the instrumented build because its individual cost is below the resolution of a single counter interval. The result divides this interval by 1000. Instrumentation is active only when `BOX64_CALLBACK_TRACK_BENCH=1`.

Install the library prerequisite and the vcpkg-packaged breakdown tool, then run:

```bash
../../1-libs/breakdown-test/run.sh --install-only
../../install-tools.sh
./run.sh
```

The runner consumes `vcpkg/installed/arm64-linux/tools/box64-callback-track-ae/box64-callback-track` and never rebuilds Box64 from a source tree. Set `BOX64_CALLBACK_TRACK` only to override that packaged executable. The default run pins each process to CPU 0 and uses five independent Box64 processes with one million address-origin checks each. Override these settings with `CPU`, `ROUNDS`, and `ITERATIONS`.
