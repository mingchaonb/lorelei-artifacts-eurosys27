# 三整数函数调用开销拆分

[English](README.md)

公开命令默认使用仓库内的 `.work/devkit`。可设置 `LORELEI_DEVKIT=/absolute/path/to/devkit` 覆盖。

本 benchmark 测量 `breakdown-test` port 提供的 `int breakdown_test(int first, int second, int third)`。函数只返回首个参数，在保留三个整数参数打包与传输过程的同时，让 host 函数体接近空操作。

先从 `1-libs` 安装 port，再运行 breakdown：

```bash
../../1-libs/breakdown-test/run.sh --install-only
./run.sh
```

breakdown runner 只使用 `evaluations/1-libs/breakdown-test` 生成的 vcpkg 安装，不会调用 vcpkg。默认运行启动五个独立 QEMU 进程，每个进程调用一百万次。原始输出、环境信息和中位数汇总写入 `results/<UTC timestamp>/`。
