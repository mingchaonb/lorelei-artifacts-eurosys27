# SDL2_mixer 2.8.2 validation (TLC + HLR)

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the official SDL2_mixer 2.8.2 shared library and the pinned SDL2 2.28.5 dependency. The directed workload plays a raw mono chunk through SDL's dummy audio driver and registers a post-effect callback plus its completion callback. Native and Hecate must both report at least one effect call, exactly one completion call, and exit zero.

```bash
QEMU=/path/to/qemu-x86_64 \
./evaluations/1-libs/sdl2-mixer/run.sh --reference --verbose
```

The Hecate lane uses TLC plus HLR for SDL2 and SDL2_mixer with TLC callback replacement disabled. The host preloads the Lorelei QEMU thread hook because SDL invokes the guest callbacks from its native dummy-audio thread. The port keeps WAVE support and disables optional external music codecs. This workload validates effect callbacks across a host-created thread and does not claim coverage of every decoder or the complete upstream suite.

The expected SDL2_mixer audit is 26 translation units, 2 CCG classes, 2 FDG classes, and 3 rewritten files.
