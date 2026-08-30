# Hecate callback address-boundary comparison

[中文版](README.zh-CN.md)

The HLR-generated `__LoreFileContext_CCG()` first compares a callback address with the emulator address boundary. A host address does not enter guest-trampoline inspection or callback reentry, making this integer address comparison the common host-callback fast path.

This experiment measures the same branch direction used by the production code. Inputs come from a fixed-size `volatile` address array, with every address on the host side. The default run pins CPU 0 and performs 100,000,000 comparisons in each of 5 rounds:

```bash
./evaluations/3-breakdown/hecate-callback-track/run.sh
```

`CPU`, `ROUNDS`, and `ITERATIONS` adjust the run scale. Evidence includes every raw round, SHA-256 values for the installed `LoreHLR` and benchmark, and per-comparison time in `summary.csv`. This value represents only the host-address boundary-comparison fast path, not the complete reentry cost of a guest callback trampoline.
