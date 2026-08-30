# libcurl 8.20.0 验证（TLC + HLR）

[English](README.md)

本配方从官方 curl 8.20.0 release 构建仅支持 HTTP 的最小 `libcurl.so.4`。定向 workload 向 loopback server 发送一次请求，通过 `curl_easy_setopt` 传递 guest write callback，要求 native 与 Hecate 均收到恰好 11 个 response byte 并返回 `CURLE_OK`。

```bash
./evaluations/1-libs/libcurl/run.sh --reference --verbose
```

TLC callback replacement 已关闭。`curl_easy_setopt` variadic extractor 和 callback metadata anchor 属于被测库配置。host thunk 对 TLC 的 integer-to-`CURLcode` enum return conversion 使用 `-fpermissive`。TLS、压缩、非 HTTP protocol、外部网络访问和完整上游 suite 不属于本声明范围。预期 audit 为 183 个 translation unit、1 个 CCG class、1 个 FDG class 和 4 个重写文件。
