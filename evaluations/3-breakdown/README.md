# Mechanism breakdown

[中文版](README.zh-CN.md)

This group provides directed microbenchmarks for the paper's mechanism-breakdown figures and functional smoke tests for Hecate integration with Blink, Box64, and FEX. It does not measure whole-application performance, and the instrumented Box64 is never used for CLI or game evaluation.

## 1. Experiment scope

| Experiment | Purpose | Default scale | Entry point |
|---|---|---|---|
| Two-argument and six-argument call breakdown | Separately measures GTL, Hecate middle-layer, QEMU, and HTL cost for one call | 5 rounds with 1,000,000 calls per arity in each round | `breakdown-test/run.sh` |
| Box64 callback address-origin breakdown | Measures each stage used by Box64 to recover a native callback from a guest bridge | 5 processes pinned to CPU 0 with 1,000,000 checks each | `box64-callback-track/run.sh` |
| Hecate callback boundary comparison | Measures HLR's fast address-boundary decision for a host callback | 5 rounds pinned to CPU 0 with 100,000,000 comparisons each | `hecate-callback-track/run.sh` |
| Hecate emulator smoke test | Validates direct calls, host callback round trips, and guest callback reentry with Blink, Box64, and FEX | 1,000 guest callback invocations per emulator | `hecate-emulators/run.sh` |

## 2. Prepare prerequisites

Install the synthetic test library and shared tools first:

```bash
./evaluations/1-libs/breakdown-test/run.sh --install-only
./evaluations/install-tools.sh
```

This provides:

- The AArch64 host library, x86-64 guest library, and headers for `breakdown-test`.
- Ordinary QEMU, Blink, Box64, and FEX packages.
- The instrumented Box64 package dedicated to the callback breakdown.

The ordinary and instrumented Box64 packages are independent. `BOX64` selects the ordinary performance build. `BOX64_CALLBACK_TRACK` only overrides the executable path used by the callback breakdown.

## 3. Two-argument and six-argument call breakdown

Run:

```bash
./evaluations/3-breakdown/breakdown-test/run.sh
```

The benchmark calls:

```c
int breakdown_test_2(int first, int second);
int breakdown_test_6(int first, int second, int third, int fourth, int fifth, int sixth);
```

Both functions return only their first argument. The runner regenerates the guest thunk, instruments both generated functions identically, and reports each argument count separately:

1. `gtl_ns`
   - Guest thunk cost.
2. `hecmid_ns`
   - Hecate runtime middle-path cost.
3. `qemu_ns`
   - QEMU magic-syscall and plugin cost.
4. `htl_ns`
   - Host thunk cost.
5. `total_ns`
   - Total cost per call.

By default, 5 rounds each start one two-argument process and one six-argument process, with 1,000,000 calls per process. Override the scale with:

```bash
ROUNDS=7 ITERATIONS=2000000 \
  ./evaluations/3-breakdown/breakdown-test/run.sh
```

## 4. Box64 callback address-origin breakdown

Run:

```bash
./evaluations/3-breakdown/box64-callback-track/run.sh
```

The host library returns a native callback. Box64 converts it to a guest-visible bridge, which is then passed back to the host. The instrumented `GetNativeOrAlt()` measures:

1. Guest ELF address check.
2. Host DSO address check.
3. Memory protection and mapping check.
4. GOT pattern check.
5. Box64 wrapper-signature check.

The first four checks run once per sample. A wrapper-signature comparison is shorter than the timer resolution, so the instrumented build repeats it 1,000 times per sample and converts the interval back to per-check cost. The host library also verifies that Box64 ultimately recovers the original native callback address.

The default CPU is 0. Override the scale, CPU, or instrumented executable with:

```bash
CPU=2 ROUNDS=7 ITERATIONS=2000000 \
BOX64_CALLBACK_TRACK=/absolute/path/to/box64-callback-track \
  ./evaluations/3-breakdown/box64-callback-track/run.sh
```

`BOX64_CALLBACK_TRACK` is an executable path, not a Boolean switch. `install-tools.sh` supplies the default path, so it normally does not need to be set.

## 5. Hecate callback address-boundary comparison

Run:

```bash
./evaluations/3-breakdown/hecate-callback-track/run.sh
```

This experiment measures the boundary comparison performed by an HLR-generated callback guard for a host address. It represents only the fast path that does not reenter a guest trampoline and complements the Box64 callback-origin breakdown in the callback figure.

## 6. Hecate emulator smoke test

Run:

```bash
./evaluations/3-breakdown/hecate-emulators/run.sh
```

For Blink, Box64, and FEX, the runner validates:

- A direct guest-to-host function call.
- A host callback returned to the guest and passed back to the host.
- A guest callback passed to the host and invoked 1,000 times.
- Callback trampolines, emulator reentry, and the magic-syscall resume path.

Override the callback count with:

```bash
ITERATIONS=5000 ./evaluations/3-breakdown/hecate-emulators/run.sh
```

`BLINK`, `BOX64`, and `FEX` override the ordinary emulator paths. This smoke test does not use the instrumented Box64.

## 7. Results and evidence

Each run writes:

```text
evaluations/3-breakdown/<experiment>/results/<UTC timestamp>/
```

The call and callback breakdowns preserve:

- Per-round stdout and stderr.
- Iteration count, process count, CPU, and tool identity.
- Raw per-operation values for every stage.
- Per-round values and medians in `summary.csv`.

The emulator smoke test preserves:

- Separate stdout and stderr for all three emulators.
- Tool paths, SHA-256 values, and vcpkg package versions.
- Callback count and fixed correctness output.

Conclusions must be recomputable from raw output. Generated programs, thunks, and installation prefixes under `.work/evaluations/` are reusable state, not paper evidence.
