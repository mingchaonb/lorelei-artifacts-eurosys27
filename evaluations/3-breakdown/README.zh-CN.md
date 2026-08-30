# 机制开销拆分

[English](README.md)

本组包含用于复现单次调用、callback 和机制开销的配方与证据。

- [`breakdown-test/`](breakdown-test/) 测量一个返回首个参数的合成三整数函数。
- [`box64-callback-track/`](box64-callback-track/) 测量 native callback 经 guest 可见 bridge 传递时，Box64 识别 callback 地址来源的开销。
