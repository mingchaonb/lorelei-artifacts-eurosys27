# openssl evaluation (TLC Only)

This recipe pins OpenSSL 3.0.22. The production targets are libcrypto.so.3 and libssl.so.3. Native AArch64 and x86-64 packages are built as shared libraries from the same official source input.

OpenSSL is the explicit exception in this migration batch. The port builds and installs only the software payload. It does not build or install upstream tests.

The runner accepts one devkit path and installs both architecture packages, then records the shared-library audit. `--install-only` is accepted for interface consistency. `--reference` writes append-only reference evidence. `--verbose` mirrors vcpkg preparation output while retaining the raw logs.

No OpenSSL test, speed benchmark, Hecate lane, or pure QEMU lane is run. This target intentionally does not carry the `[ALL TESTS PASSED]` marker.

```bash
./run.sh --reference /path/to/lorelei-devkit
```
