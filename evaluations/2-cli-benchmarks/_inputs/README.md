# Input provenance

[中文版](README.zh-CN.md)

Generated inputs are stored in this directory during a local run and are not committed. Run `../_common/prepare-inputs.sh` to reproduce them. `manifest.json` records every generated file's byte size and SHA-256 digest.

The compression and OpenSSL inputs are generated deterministically by Python. The FFmpeg workloads use fixed excerpts derived outside the measured region from the source described by `media-source.json`.
