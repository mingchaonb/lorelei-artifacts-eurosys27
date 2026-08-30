# 输入来源

[English](README.md)

本地运行时，生成的输入保存在此目录且不提交。运行 `../_common/prepare-inputs.sh` 可重新生成。`manifest.json` 记录每个生成文件的字节数和 SHA-256。

压缩与 OpenSSL 输入由 Python 确定性生成。FFmpeg workload 使用从 `media-source.json` 所述来源派生的固定片段，派生过程位于计时区间之外。
