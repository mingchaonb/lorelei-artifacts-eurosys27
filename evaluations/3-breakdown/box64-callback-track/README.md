# Box64 callback address-origin breakdown

This benchmark measures the address-origin checks in Box64 `GetNativeOrAlt()`. It uses the synthetic `breakdown-test` library installed by `evaluations/1-libs/breakdown-test`.

The host library returns a native three-integer callback. The Box64 wrapper converts it to a guest-visible bridge. The benchmark then passes that bridge back through another wrapped function. Box64 must reject the address as a guest ELF address, reject it as a host DSO address, confirm that it is mapped, reject the GOT pattern, and recognize the Box64 wrapper signature. The host library verifies that Box64 recovered the original native callback address.

The first four checks execute once per sample. The final wrapper-signature comparison is repeated 1000 times inside the instrumented branch because its individual cost is below the resolution of a single counter interval. The result divides this interval by 1000. Instrumentation is active only when `BOX64_CALLBACK_TRACK_BENCH=1`.

Prepare the port and the dedicated Box64 branch, then run:

```bash
../../1-libs/breakdown-test/run.sh --install-only /path/to/lorelei-devkit
BOX64_SOURCE=/path/to/box64-breakdown ./run.sh /path/to/lorelei-devkit
```

The default run pins each process to CPU 0 and uses five independent Box64 processes with one million address-origin checks each. Override these settings with `CPU`, `ROUNDS`, and `ITERATIONS`.
