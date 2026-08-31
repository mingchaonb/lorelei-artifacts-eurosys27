# libuv 1.52.1 验证（TLC + HLR）

[English](README.md)

本配方构建官方 libuv 1.52.1 共享库。定向 workload 提交一次 `uv_queue_work`，要求 worker callback 在 host thread pool 执行、completion callback 在 event loop 执行，然后在 native 与 Hecate 都关闭 loop 并 shutdown libuv。

```bash
./evaluations/1-libs/libuv/run.sh --verbose
```

TLC callback replacement 已关闭，HLR 重写 production 共享库 closure。经过审查的 patch 让 libuv host 内部 static worker table 保持原始 host 地址，因为这些函数不跨 guest boundary。network、filesystem、process、signal、synchronization、platform-specific backend 和完整上游 suite 不属于本定向 callback workload。预期 audit 为 35 个 translation unit、7 个 CCG class、6 个 FDG class 和 14 个重写文件。
