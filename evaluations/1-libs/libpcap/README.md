# libpcap 1.10.6 validation (TLC + HLR)

This recipe fetches the official libpcap release through the repository vcpkg overlay, rewrites its exact shared-library closure with HLR, generates a TLC thunk with callback replacement disabled, and runs one offline-capture workload in native and Hecate paths.

```bash
./evaluations/1-libs/libpcap/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/libpcap/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/libpcap/run.sh --install-only /path/to/lorelei-devkit
```

The fixed input contains one captured packet with a four-byte payload. Success requires one callback, four captured bytes, first byte `0x01`, and exit status zero in both lanes. The recipe validates the five listed APIs and callback boundary used by this workload, not the complete upstream test suite.

The production closure includes generated `grammar.c` and `scanner.c`. The expected audit is 19 translation units, 1 CCG class, 1 FDG class, and 4 rewritten files. A reviewed post-HLR patch keeps generated headers after libpcap's feature configuration include.
