# libmaxminddb 1.13.3 validation (TLC Only) [ALL TESTS PASSED]

[中文版](README.zh-CN.md)

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This recipe builds the pinned shared library for AArch64 and x86-64, generates thunks for the APIs used by the upstream 26-test CTest suite, and runs the suite in native and Hecate lanes. `MMDB_get_value` uses a null-terminated custom variadic path extractor. `MMDB_vget_value` converts the guest `va_list` to the array-form API before crossing the ABI boundary. The private `data-pool-t` executable contributes four additional exported test symbols.

The database input is MaxMind-DB commit `819f226fbf8290c2b171ac077e6e050618dd3574`, whose GitHub archive SHA-512 is `0d3bf40b95e6921f0d868a747dceca43ea52dac4759470756e67f8af6191900859f3bb2108b494d52a83b5a12d252469ffffd37dd349afa4f8dc5e2d2ab1cf13`. The accompanying libtap input is commit `b53e4ef5257f80e881762b6143834d8aae29da1a`, whose archive SHA-512 is `4e8da92858fab7a3c04d86b3a62581301e520c907ee5284b7cc55e32affb4582f94f9c4326054462e361cda95ee4004083e2d52d3accdb2e03d062c1365c79c3`. CLI tools and unsupported APIs are excluded. No HLR extension is loaded.

Run `./evaluations/1-libs/libmaxminddb/run.sh` to install both architectures, generate the TLC thunk, and run all 26 configured upstream tests in native and Hecate lanes. The vcpkg port installs the test binaries and pinned database inputs under `tools/libmaxminddb/upstream-tests`. Pass `--install-only` to stop after package installation and thunk generation.

All 26 configured upstream tests pass in native and Hecate lanes. The negative-indent test writes only to `/dev/null`. Its guest entry returns the documented success result without passing a guest `FILE *` to host glibc. This workload-specific handling does not claim arbitrary cross-ABI stream support.
