# LibTomMath 1.3.0 验证（TLC + HLR）

[English](README.md)

本配方构建官方 LibTomMath 1.3.0 共享库。定向 workload 通过 `mp_rand_source` 安装确定性的 guest random-source callback，要求随后两次 `mp_rand` 都调用它，并比较 native 与 Hecate 的 multiplication 与 hexadecimal conversion 结果。

```bash
./evaluations/1-libs/libtommath/run.sh --reference --verbose
```

TLC callback replacement 已关闭。HLR 将内部 static random-source initializer 检测为 FDG，但经过审查的 patch 保留该 host 内部指针的原始值。CCG 处理 guest 安装的 persistent callback。demo 与完整 arithmetic regression suite 不属于本声明。预期 audit 为 154 个 translation unit、1 个 CCG class、1 个 FDG class 和 3 个重写文件。
