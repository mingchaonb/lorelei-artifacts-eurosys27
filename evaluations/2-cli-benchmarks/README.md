# Command-line workload reproduction

This evaluation reproduces the eight command-line workloads used by the paper. Every timed program and shared library comes from the matching `evaluations/1-libs` installation. The separate official FFmpeg under `vcpkg/installed/arm64-linux` is an input-preparation tool and is never timed.

The workloads are:

1. FFTW
2. zstd compression
3. zlib compression
4. OpenSSL SHA-256
5. FFmpeg with libmp3lame
6. FFmpeg with libfdk_aac
7. FFmpeg with libvorbis
8. FFmpeg with libx264

Each recipe records at least five repetitions, full commands, exit status, wall-clock time, input size and SHA-256, package versions, and emulator revisions. A single timed repetition has a hard 180-second limit. Workload sizes are calibrated so the pure QEMU and pure Blink lanes both remain below that limit.

## Execution lanes

The comparison keeps the native and emulated software versions identical:

- native AArch64
- pure QEMU x86-64 emulation
- pure Blink x86-64 emulation
- pure Box64 x86-64 emulation
- pure FEX x86-64 emulation
- QEMU with Hecate
- Blink with Hecate
- Box64 with Hecate
- FEX with Hecate

The Hecate environment for Blink, Box64, and FEX follows `evaluations/3-breakdown/hecate-emulators`. `LORELEI_DEVKIT` defaults to the sibling `../lorelei-ae/build/install`. Emulator paths default to the pinned vcpkg tools installed by `evaluations/install-tools.sh` and can be overridden with `QEMU`, `BLINK`, `BOX64`, and `FEX`.

## Inputs

Prepare all deterministic and media-derived inputs once:

```bash
./evaluations/2-cli-benchmarks/_common/prepare-inputs.sh
```

The media source is the public YouTube video identified in [`_inputs/media-source.json`](_inputs/media-source.json). The download itself and all derived binary inputs are deliberately ignored by Git. The preparation command records their exact sizes and SHA-256 digests.

The system `yt-dlp` must be recent enough to read current YouTube metadata. Ubuntu's old package may fail. The script reports this explicitly and accepts `YT_DLP=/absolute/path/to/yt-dlp`.

## Running

Run every available workload sequentially:

```bash
./evaluations/2-cli-benchmarks/run-all.sh
```

The aggregate runner keeps controller state below `.work/evaluations/2-cli-benchmarks-batch/`. Repeating the same command skips successful workloads and retries failures or interruptions. Use `--restart` to archive that state and start again. Interactive terminals show the three most recent results, the active workload, and aggregate progress at the bottom. Use `--plain` for ordinary log output.

The same runner can create author-side evidence, select lanes, or only prepare workload prerequisites:

```bash
./evaluations/2-cli-benchmarks/run-all.sh --reference
./evaluations/2-cli-benchmarks/run-all.sh --lanes native,qemu,qemu-hecate
./evaluations/2-cli-benchmarks/run-all.sh --install-only
```

Local output is written below each workload's `results/`. Reference output uses `reference-results/` and can be committed explicitly.

Remove generated evaluator or author-side result directories with the matching guarded cleanup script. Pass `--dry-run` to inspect the exact targets first.

```bash
./evaluations/2-cli-benchmarks/delete-all-results.sh
./evaluations/2-cli-benchmarks/delete-all-reference-results.sh
```
