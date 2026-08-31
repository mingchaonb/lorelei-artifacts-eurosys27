# libarchive 3.8.9 验证（TLC + HLR）

[English](README.md)

本配方构建官方 libarchive 3.8.9 共享库。定向 workload 在内存创建受限 PAX archive，再使用 `archive_read_open2` 和 guest 提供的 open、read、skip、close callback 打开它。native 与 Hecate 都必须恢复 `payload.txt`、其 24-byte payload、1 次 open callback、5 次 read callback 和 1 次 close callback。

```bash
./evaluations/1-libs/libarchive/run.sh --verbose
```

TLC callback replacement 已关闭。HLR 重写 production 共享库 closure，经过审查的 patch 则让 libarchive host 内部 static callback table 保留原始 host 地址。命令行工具、上游 regression 测试、crypto backend、XML parser、外部压缩库、文件系统 archive I/O，以及内存 PAX tar 以外的格式不属于本定向评测。

预期 audit 为 123 个 translation unit、3 个 CCG class、3 个 FDG class和 10 个重写文件。
