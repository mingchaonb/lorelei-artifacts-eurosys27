# libstemmer 3.1.1 validation (TLC Only) [ALL TESTS PASSED]

The port builds a real shared `libstemmer.so.0` from the upstream PIC objects. It does not treat the Snowball static archive as the deliverable. The workload dynamically links the upstream `stemwords` program and runs 57 language and encoding checks against `snowball-data` commit `a0ec0d0a2839ec885878868de20fcb63209d92b0`. Its GitHub archive SHA-512 is `de068e9521e339595e0805fc4524a972a8862ccc47b4731f98913f4663bdd08e1608c28183d82af1de435ac6610b3a80cac19adfcc088119d6ebe4c319c8e41b`.

Success requires all generated stemming checks to pass in native and Hecate lanes. Snowball compiler self-tests are outside the DSO claim. No HLR extension is used.

Run `./evaluations/1-libs/libstemmer/run.sh /path/to/lorelei-devkit` to install both architectures, generate the TLC thunk, and run all 57 upstream language and encoding checks in native and Hecate lanes. The vcpkg port installs `stemwords` and the pinned corpus under `tools/libstemmer/upstream-tests`. Pass `--install-only` to stop after package installation and thunk generation.
