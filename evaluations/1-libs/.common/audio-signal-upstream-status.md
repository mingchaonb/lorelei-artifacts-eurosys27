# Audio and Signal Upstream Test Status

Date: 2026-08-29

This status expands the directed TLC Only workloads to the complete set of upstream tests that exercise a shared library in the artifact configuration. The Hecate gate does not include a pure QEMU baseline.

## Native ARM64

- fftw3 passes CMake's two official bench cases, `32x64` and `ib256`.
- libaec passes all 7 CTest tests.
- libcerf passes all 9 CTest executables.
- libogg passes the `test_bitwise` and `test_framing` self-tests.
- libsamplerate passes all 13 CTest tests.
- libsndfile passes all 143 CTest tests with external codecs and MPEG disabled in the native diagnostic build.
- soxr passes all 9 CTest tests with the artifact's scalar configuration.
- The libsyn123-only component registers no standalone tests. Its `resample_total` test passes through the mpg123 source build.
- libvorbis passes upstream `make check`, including 5 shared-book checks and 528 channel, quality, and rate encode-decode cases, when run serially.
- libvorbisfile has no dedicated upstream test registered by the 1.3.7 build. The combined libvorbis test does not import any `ov_*` symbol and therefore is not attributed to libvorbisfile.
- mpg123 passes all 6 Automake tests.
- Opus passes all 5 upstream CTest executables in the native diagnostic build.

The artifact carries minimal post-fetch patches that allow libsndfile and Opus to build their tests with shared libraries. Tests that only call non-exported internal functions remain internal unit tests and are not counted as public shared-ABI Hecate coverage.

The first parallel libvorbis `make check` hit a dependency-file race caused by a recursive `make test`. A serial rerun passed. This was a build-harness race, not a test failure.

## Hecate x64 guest

- FFTW passes both upstream CMake cases, `32x64` and `ib256`. The shared test patch disables its internal planner hook and three direct ELF data-object reads because TLC forwards functions rather than global data objects. Public planning, execution, and result verification remain enabled.
- libaec passes all 7 upstream tests. `check_code_options` completes when allowed to run beyond the earlier 60-second exploratory cutoff. `sampledata.sh` uses an explicit Hecate launcher for `graec`.
- libcerf passes all 9 upstream CTest executables, including 142,515 checks in `realtest_c`.
- libogg passes both self-tests after a test-only shared-build patch separates the self-test body from the in-file implementation and links it to `libogg.so.0`.
- libsamplerate passes all 13 upstream CTest executables after expanding the thunk's public API surface. The final build explicitly enables FFTW, so `snr_bw_test` performs its SNR and bandwidth checks instead of taking its no-FFTW early exit.
- libsndfile passes all 141 public shared-DSO CTest tests. `test_main` and `g72x_test` call non-exported internal functions and remain native internal unit tests. `stdio_test` and `pipe_test` use an explicit Hecate child launcher for their x64 subprocesses.
- soxr passes all 9 upstream cases. Eight cases run both the resampler and vector-comparison child executables through the explicit Hecate launcher.
- The mpg123 1.33.7 source suite has 6 registered tests. Four tests import `libmpg123.so.0` and one imports `libsyn123.so.0`, and all 5 shared-DSO tests pass through Hecate. `textprint` links only test-local formatting code, so its native pass is retained but it is not counted as shared-DSO Hecate evidence.
- libvorbis passes all 528 channel, quality, and sample-rate encode-decode combinations through the `libvorbisenc`, `libvorbis`, and `libogg` thunks. Its five `test_sharedbook` checks compile the private implementation directly and remain native internal checks.
- libvorbisfile has zero dedicated registered upstream tests. Its separate directed `ov_*` workload remains the applicable Hecate evidence.
- Opus passes all 4 public shared-DSO upstream tests. The four tests are decoder, padding, API, and encoder. `test_opus_extensions` calls non-exported internal functions and remains a native internal unit test.

The libsamplerate expansion adds `src_clone`, `src_get_channels`, `src_get_description`, `src_get_name`, `src_get_version`, and `src_is_valid_ratio`.

Raw logs and the machine-readable summary are in `results/library-tests/audio-signal-upstream/20260829T200308Z`.

## Remaining work

- Consolidate the exploratory build commands into a public clean-build runner. The current raw result reruns the finished test executables but does not yet reconstruct every x64 test build from an empty work directory.
- Keep disabled libsndfile codecs and soxr scalar-backend exclusions aligned with each artifact port's claim.
- Preserve the boundary between public shared-DSO Hecate evidence, zero-test targets, and native-only internal implementation tests.
