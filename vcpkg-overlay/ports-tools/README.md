# AE tool ports

This overlay contains executable tools used by the evaluation harness. It is separate from `../ports`, which contains the libraries under test and their Hecate build recipes.

The emulator ports are pinned to the reviewed `ae` commits in the `mingchaonb` forks. They install only the executables needed by the public evaluation paths under `tools/<port>/`. The repository-level installer also selects the built-in vcpkg FFmpeg port, so the native FFmpeg command is not built from the Hecate library-test recipe.

Install the host-side build prerequisites once:

```bash
sudo apt install -y build-essential clang cmake ninja-build pkg-config python3 libglib2.0-dev libdw-dev
```

Use the public installer from any working directory:

```bash
./evaluations/install-tools.sh
```

Installed executable paths are:

1. `vcpkg/installed/arm64-linux/tools/qemu-ae/qemu-x86_64`
2. `vcpkg/installed/arm64-linux/tools/blink-ae/blink`
3. `vcpkg/installed/arm64-linux/tools/box64-ae/box64`
4. `vcpkg/installed/arm64-linux/tools/fex-ae/FEX`
5. `vcpkg/installed/arm64-linux/tools/ffmpeg/ffmpeg`
