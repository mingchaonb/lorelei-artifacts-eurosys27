# breakdown-test 1.0.0 安装

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

该合成 port 支持单次调用和 callback 地址来源 breakdown。它导出 `int breakdown_test(int first, int second, int third)`，忽略后两个参数并返回首个参数。另有两个辅助函数分别返回 native callback，以及验证经 wrapper 传递的地址能恢复为该 callback。

通过共用 vcpkg overlay 安装 ARM64 host DSO 和 x86-64 link-time DSO：

```bash
./evaluations/1-libs/breakdown-test/run.sh --install-only
```

随后由 `evaluations/3-breakdown/breakdown-test` 配方使用该安装 prefix。breakdown runner 自身不调用 vcpkg。
