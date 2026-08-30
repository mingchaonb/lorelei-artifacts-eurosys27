# Blink、Box64 与 FEX 的 Hecate 支持烟测

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

该测试复用 `breakdown-test` 的三参数整数接口，并增加两个 callback 检查。第一个检查把 host callback 返回 guest 后再传回 host，验证地址来源判断不会重复包装 host 地址。第二个检查把 guest callback 传给 host 并实际调用 1000 次，验证 callback trampoline、emulator 重入口和 magic syscall resume 路径。

先运行 `evaluations/1-libs/breakdown-test/run.sh --install-only`，再运行：

```bash
./evaluations/3-breakdown/hecate-emulators/run.sh
```

runner 默认使用 `evaluations/install-tools.sh` 安装的 Blink、Box64 和 FEX，以及同级 `lorelei-ae` 的 devkit。可以用 `BLINK`、`BOX64`、`FEX` 和 `LORELEI_DEVKIT` 覆盖路径。原始输出、工具哈希和 vcpkg 包版本保存在本目录的 `results/<UTC 时间>/`。
