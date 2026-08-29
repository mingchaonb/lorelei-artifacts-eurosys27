# libyaml 0.2.5 validation (TLC Only) [ALL TESTS PASSED]

This recipe runs the two tests enabled by the pinned upstream CMake configuration. They validate version reporting and parser buffer handling. Native and Hecate CTest lanes must both complete successfully.

The internal `yaml_parser_update_buffer` declaration is included because the upstream reader test uses it. Tools, examples, and APIs outside those tests are excluded. No HLR extension is used.

Run `./evaluations/1-libs/libyaml/run.sh /path/to/lorelei-devkit` to install both architectures, generate the TLC thunk, and run both tests registered by the upstream CMake configuration in native and Hecate lanes. The vcpkg port installs them under `tools/libyaml/upstream-tests`. Pass `--install-only` to stop after package installation and thunk generation.
