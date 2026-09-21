# Hecate support smoke test for Blink, Box64, and FEX

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This test reuses the three-argument integer interface from `breakdown-test` and adds two callback checks. The first passes a host callback back to the guest and then to the host again, which verifies that the address-origin check does not wrap a host address a second time. The second passes a guest callback to the host and invokes it 1000 times, which exercises the callback trampoline, emulator reentry, and the magic syscall resume path.

Run `evaluations/1-libs/breakdown-test/run.sh --install-only` first, then:

```bash
./evaluations/3-breakdown/hecate-emulators/run.sh
```

The runner uses the Blink, Box64, and FEX installed by `evaluations/install-tools.sh` and the repository-local `.work/devkit` by default. Override the paths with `BLINK`, `BOX64`, `FEX`, and `LORELEI_DEVKIT`. Raw output, tool hashes, and vcpkg package versions are saved under `results/<UTC time>/` in this directory.
