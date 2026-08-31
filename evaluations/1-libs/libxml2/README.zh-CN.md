# libxml2 2.15.3 验证（TLC + HLR）

[English](README.md)

本配方构建官方 libxml2 2.15.3 共享库。定向 workload 分两段向 push parser 提交 XML，要求 native 与 Hecate 都得到 2 次 start-element callback、2 次 end-element callback 和 7 byte character data。

```bash
./evaluations/1-libs/libxml2/run.sh --verbose
```

TLC callback replacement 已关闭。HLR 将内部 SAX 与 parser callback table 检测为 FDG，经过审查的 patch 保留其原始 host pointer。Python、程序、可选压缩、外部文档和完整上游 suite 不属于本定向共享库 workload。预期 audit 为 37 个 translation unit、23 个 CCG class、20 个 FDG class 和 33 个重写文件。
