# breakdown-test 1.0.0 installation

This synthetic port supports the single-call breakdown. It exports `int breakdown_test(int first, int second, int third)`. The function ignores the last two arguments and returns the first argument.

Install the ARM64 host DSO through the common vcpkg overlay:

```bash
./evaluations/1-libs/breakdown-test/run.sh --install-only /path/to/lorelei-devkit
```

The `evaluations/3-breakdown/breakdown-test` recipe then consumes this installation prefix. The breakdown runner does not invoke vcpkg.
