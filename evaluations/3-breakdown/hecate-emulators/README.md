# Blink、Box64 与 FEX 的 Hecate 支持烟测

Public commands use the sibling `../lorelei-ae/build/install` devkit by default. Set `LORELEI_DEVKIT=/absolute/path/to/devkit` to override it.

该测试复用 `breakdown-test` 的三参数整数接口，并增加两个 callback 检查。第一个检查把 host callback 返回 guest 后再传回 host，验证地址来源判断不会重复包装 host 地址。第二个检查把 guest callback 传给 host 并实际调用 1000 次，验证 callback trampoline、emulator 重入口和 magic syscall resume 路径。

先运行 `evaluations/1-libs/breakdown-test/run.sh --install-only`，再运行：

```bash
./evaluations/3-breakdown/hecate-emulators/run.sh
```

runner 默认使用同级 `blink-ae`、`box64-ae`、`FEX-ae` 和 `lorelei-ae`。可以用 `BLINK`、`BOX64`、`FEX` 或第一个位置参数覆盖路径。原始输出和仓库提交号保存在本目录的 `results/<UTC 时间>/`。
