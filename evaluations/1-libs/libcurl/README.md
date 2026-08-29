# libcurl 8.20.0 validation (TLC + HLR)

This recipe builds a minimal HTTP-only `libcurl.so.4` from the official curl 8.20.0 release. The directed workload sends one request to a loopback server, passes a guest write callback through `curl_easy_setopt`, and requires exactly 11 response bytes with `CURLE_OK` in both native and Hecate paths.

```bash
./evaluations/1-libs/libcurl/run.sh --reference --verbose /path/to/lorelei-devkit
```

TLC callback replacement is disabled. The `curl_easy_setopt` variadic extractor and callback metadata anchor are part of the measured library configuration. The host thunk uses `-fpermissive` for TLC's integer-to-`CURLcode` enum return conversion. TLS, compression, non-HTTP protocols, external network access, and the complete upstream suite are outside this claim-scoped workload.

The expected audit is 183 translation units, 1 CCG class, 1 FDG class, and 4 rewritten files.
