# Mechanism breakdown

This group contains reproducible recipes and evidence for individual call, callback, and mechanism costs.

- [`zlib-version/`](zlib-version/) measures a minimal `zlibVersion()` call through the direct QEMU syscall bridge.
- [`breakdown-test/`](breakdown-test/) measures a synthetic three-integer function that returns its first argument.
