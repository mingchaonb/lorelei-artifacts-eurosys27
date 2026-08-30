# utf8proc 2.11.3 验证（仅 TLC）[ALL TESTS PASSED]

[English](README.md)

workload 运行全部 10 个上游测试程序，包括 custom mapping callback，以及 Unicode 17.0.0 normalization 与 grapheme-break conformance。callback replacement 由 TLC 生成，不使用 HLR。

vector 固定为 `https://www.unicode.org/Public/17.0.0/ucd/NormalizationTest.txt` 与 `https://www.unicode.org/Public/17.0.0/ucd/auxiliary/GraphemeBreakTest.txt`，运行前校验：

```text
NormalizationTest.txt SHA-512: aa62fef9d78f0fd12e0b98fbc174874e90acf60fda9e91ed542fbb610b2e8257efa20ed43728f3faf3dff0950434b85f539dfaceb161bde5875208ae7a66f758
GraphemeBreakTest.txt SHA-512: 28275f1b5c0b74bdf1486a6c68fea6f62e98b88092612e94d36d5aa439de67f57e87b6841d3b1a7dc49dede272d79a22ef4ddb163a51557c0c2e45bb1fc9b4e2
```

其他 Unicode 版本与可选 static output 排除。运行 `./evaluations/1-libs/utf8proc/run.sh` 安装两个架构、生成 TLC thunk 并在两条 lane 运行 10 项测试。port 将程序和固定 vector 安装到 `tools/utf8proc/upstream-tests`。normalization helper 返回由 host 分配且由上游测试直接 `free` 的字符串，因此 Hecate 加载共享 allocator libc shim。`--install-only` 在安装和 thunk 生成后停止。
