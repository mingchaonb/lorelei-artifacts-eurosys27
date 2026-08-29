# MD4C 0.5.3 validation (TLC Only) [ALL TESTS PASSED]

This recipe fetches the official MD4C 0.5.3 release through the pinned vcpkg overlay, builds shared libraries for AArch64 and x86-64, generates TLC thunks, and executes the same directed workload in native and Hecate lanes. It does not create an HLR feature, run LoreHLR, or load an HLR extension.

## Commands

```bash
./evaluations/1-libs/md4c/run.sh /path/to/lorelei-devkit
./evaluations/1-libs/md4c/run.sh --reference --verbose /path/to/lorelei-devkit
./evaluations/1-libs/md4c/run.sh --install-only /path/to/lorelei-devkit
./evaluations/1-libs/md4c/run-upstream.sh --reference /path/to/lorelei-devkit
```

## Workload and scope

The workload covers headings, lists, emphasis and links rendered through libmd4c-html with repeated synchronous output callbacks. Success requires exit status zero and byte-identical output in native and Hecate lanes.

The parser is reached as the HTML DSO dependency. The default runner continues with all 818 configured upstream spec, regression, extension, and pathological cases through the dynamically linked `md2html` test driver. The standalone `run-upstream.sh` runs only that phase.
