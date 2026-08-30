# breakdown-test 1.0.0 installation

Public commands use the repository-local `.work/devkit` by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

This synthetic port supports the single-call and callback-origin breakdowns. It exports `int breakdown_test(int first, int second, int third)`. The function ignores the last two arguments and returns the first argument. Two additional helpers return a native callback and verify that an address passed through a wrapper resolves back to that callback.

Install the ARM64 host DSO and x86-64 link-time DSO through the common vcpkg overlay:

```bash
./evaluations/1-libs/breakdown-test/run.sh --install-only
```

The `evaluations/3-breakdown/breakdown-test` recipe then consumes this installation prefix. The breakdown runner does not invoke vcpkg.
