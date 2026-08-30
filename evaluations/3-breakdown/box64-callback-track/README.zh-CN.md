# Box64 callback 地址来源开销拆分

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本 benchmark 测量 Box64 `GetNativeOrAlt()` 中的地址来源检查。它使用 `evaluations/1-libs/breakdown-test` 安装的合成 `breakdown-test` 库。

host 库返回一个 native 三整数 callback。Box64 wrapper 将其转换为 guest 可见 bridge，benchmark 再通过另一个包装函数把 bridge 传回。Box64 依次确认该地址不是 guest ELF 地址、不是 host DSO 地址、已经映射、不匹配 GOT 模式，最后识别 Box64 wrapper 签名。host 库同时验证 Box64 最终恢复了原始 native callback 地址。

前四项检查每个样本执行一次。单次 wrapper 签名比较短于计数器分辨率，因此插桩版本在每个样本内重复 1000 次，再将区间除以 1000。只有设置 `BOX64_CALLBACK_TRACK_BENCH=1` 时才启用插桩。

安装库依赖和 vcpkg 打包的 breakdown 工具，然后运行：

```bash
../../1-libs/breakdown-test/run.sh --install-only
../../install-tools.sh
./run.sh
```

runner 使用 `vcpkg/installed/arm64-linux/tools/box64-callback-track-ae/box64-callback-track`，不会从源码树重新构建 Box64。只有需要替换已打包程序时才设置 `BOX64_CALLBACK_TRACK`。默认运行将每个进程固定在 CPU 0，启动五个独立 Box64 进程，每个进程执行一百万次地址来源检查。可用 `CPU`、`ROUNDS` 和 `ITERATIONS` 调整。
