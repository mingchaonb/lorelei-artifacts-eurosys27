# Lorelei AE vcpkg overlay

This directory is the shared package layer for version 2 library validation. All tested libraries use ports below `ports/`, and all AE target definitions use triplets below `triplets/`.

The repository-local `vcpkg/` checkout is the only supported vcpkg instance. The currently validated checkout is commit `3f7b5a12ef0a55e7b59339b2b69cac4b56d6dbf9`.

## Initial setup

```bash
git clone https://github.com/microsoft/vcpkg.git vcpkg
git -C vcpkg checkout 3f7b5a12ef0a55e7b59339b2b69cac4b56d6dbf9
./vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

Package recipes do not clone upstream projects. A port pins the upstream release and checksum, then vcpkg owns download, extraction, patching, build, installation, and package caching.

## Layout

```text
vcpkg-overlay/
├── ports/
│   └── sdl2/
└── triplets/
    ├── arm64-linux-ae.cmake
    ├── x64-linux-ae.cmake
    └── x64-linux-ae-toolchain.cmake
```

The runner passes these directories explicitly with `--overlay-ports` and `--overlay-triplets`. Separate install roots allow TLC and HLR to package different host builds without collisions.

## Direct package commands

The public library recipe normally runs these commands. They are also available for package-level diagnosis:

```bash
./vcpkg/vcpkg install \
  'sdl2[tests]:arm64-linux-ae' \
  --overlay-ports=vcpkg-overlay/ports \
  --overlay-triplets=vcpkg-overlay/triplets
```

Public evaluation runners read `LORELEI_DEVKIT` and export the internal `LORELEI_DEVKIT` value for vcpkg. Direct guest and HLR package commands require `LORELEI_DEVKIT` explicitly:

```bash
export LORELEI_DEVKIT=/path/to/devkit
./vcpkg/vcpkg install \
  'sdl2[tests]:x64-linux-ae' \
  --overlay-ports=vcpkg-overlay/ports \
  --overlay-triplets=vcpkg-overlay/triplets
```
