# Expat 2.8.2 validation (TLC + HLR)

This recipe fetches the official Expat release through the repository vcpkg overlay, rewrites the seven production translation units with HLR, generates a TLC thunk with callback replacement disabled, and runs the same directed parser workload in native and Hecate paths.

## Commands

```bash
./evaluations/1-libs/expat/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/expat/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/expat/run.sh --install-only /path/to/lorelei-devkit
```

`QEMU=/path/to/qemu-x86_64` may select a development emulator when it is not installed in the devkit.

## Workload and scope

The workload parses `<root><item>lorelei</item></root>` and registers element-start, element-end, and character-data callbacks. Success requires two start callbacks, two end callbacks, seven text bytes, and exit status zero in both lanes.

The recipe validates the nine listed Expat APIs and three callback signatures used by this workload. It does not claim the complete upstream test suite. Historical evidence records 3 CCG classes, 0 FDG classes, and 1 rewritten production file. Each new run retains the generated HLR and TLC records so these values can be audited again.
