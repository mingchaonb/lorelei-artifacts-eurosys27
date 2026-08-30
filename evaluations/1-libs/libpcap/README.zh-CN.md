# libpcap 1.10.6 验证（TLC + HLR）

[English](README.md)

本配方通过仓库 vcpkg overlay 获取官方 libpcap release，使用 HLR 重写准确的共享库 closure，在关闭 callback replacement 的情况下生成 TLC thunk，并于 native 与 Hecate 路径运行一个 offline-capture workload。

```bash
./evaluations/1-libs/libpcap/run.sh
./evaluations/1-libs/libpcap/run.sh --reference --verbose
./evaluations/1-libs/libpcap/run.sh --install-only
```

固定输入含一个具有 4-byte payload 的 captured packet。两条 lane 都必须出现 1 次 callback、4 个 captured byte、首字节 `0x01`，并以状态 0 退出。配方验证该 workload 使用的 5 个 API 和 callback boundary，不声明覆盖完整上游 suite。

production closure 包含生成的 `grammar.c` 与 `scanner.c`。预期 audit 为 19 个 translation unit、1 个 CCG class、1 个 FDG class 和 4 个重写文件。经过审查的 HLR 后 patch 让生成的 header 位于 libpcap feature configuration include 之后。
