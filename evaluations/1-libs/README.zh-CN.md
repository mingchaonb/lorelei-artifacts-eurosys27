# 库评测

[English](README.md)

本组以运行每个选定库在当前配置构建后能够发现的全部上游测试为目标。若某项测试从根本上依赖不支持的原子操作、锁、signal、设备或类似的 scope 外机制，可以在文档明确说明后排除。

## 单库契约

每个库目录必须提供：

1. README，说明固定的上游 release、机制路径、配置后的上游测试集、预期结果和排除项。
2. 自包含的 `run.sh` 入口，读取 `LORELEI_DEVKIT`，默认指向仓库内的 `.work/devkit`。
3. 在适用时支持 `--install-only`、`--reference` 和 `--verbose`。
4. 仓库级 vcpkg overlay port，从官方 release 获取源码，并从自身 `patches/` 应用经过审查的 patch。
5. port 把所有配置后的上游测试安装到 `tools/<port>/upstream-tests`。若上游没有测试安装规则，port 增加规则或应用位于 `vcpkg-overlay/ports/<port>/patches/` 的最小 patch。
6. 只从两个安装 prefix 运行测试。`run.sh` 不得从上游源码树或 vcpkg buildtree 重新构建测试。
7. 对同一安装测试 manifest 生成对称的 native AArch64 和 Hecate 结果。绝不运行纯 QEMU 或 full-emulation lane。
8. 使用 HLR 的 Hecate 库在生成 TLC metadata 时关闭 callback replacement。
9. 保留只追加的原始日志、环境身份、配置 LOC、HLR 与 TLC audit 记录和机器可读汇总。
10. 在 package 局部定义 result 与 reference-result 策略。生成证据的忽略规则不得写入仓库根 `.gitignore`。
11. 只有全部未排除的配置测试在两条 lane 都没有失败时，README 第一行才添加 `[ALL TESTS PASSED]`。
12. 全仓库共享 `vcpkg/downloads` 源码归档缓存。每个库和 lane 的 install、buildtree 与 package root 仍隔离在 `.work/evaluations`。

## 迁移顺序

1. `sdl2`，完成。
2. `expat`，完成，并作为第一个普通库模板。
3. `libpcap`，完成。
4. `libevent`，完成。
5. `libcurl`，完成。
6. `libtommath`，完成。
7. `sqlite3`，完成。
8. `libxml2`，完成。
9. `libuv`，完成。
10. `wavpack`，完成。
11. `libarchive`，完成。
12. `sdl2-image`，完成。
13. `sdl2-mixer`，完成。
14. `sdl2-ttf`，完成。它是 HLR 零命中 audit，不计为 HLR 转换 DSO。
15. `ffmpeg`，由一个库配方和一个包含七个独立重写 DSO context 的 overlay port 实现。单命令参考运行在两条结果 lane 完成全部 151 项注册测试，其中 131 项通过，20 项与文档规定的 native 配置基线一致，没有 Hecate 独有失败。

FFmpeg 的四个 encoder 性能 workload 也位于 `../2-cli-benchmarks/ffmpeg/`。该 workload 分组不能替代 `ffmpeg/` 中的上游 FATE 验证。

## 完成规则

只有 clean one-command run 成功，且 reference 目录包含足以重新计算汇总的原始证据后，目标才能从 planned 变为 complete。`results/library-tests/` 中的历史结果只是迁移输入，不能替代新配方。

## Inventory audit

共享 inventory helper 从每个配方自己的 vcpkg package 目录统计真实 ELF 文件，不重复计算 `.so` 软链接。all-tests 分子只从 README 第一行的 `[ALL TESTS PASSED]` 标记推导：

```bash
./evaluations/1-libs/_common/summarize-library-inventory.sh
```

2026 年 8 月 30 日进行非 graphics audit 时，`glvnd` 与 `vulkan-loader` 正由独立 evaluation lane 迁移，合成 `breakdown-test` port 也不作为 library package。对应命令和快照为：

```bash
./evaluations/1-libs/_common/summarize-library-inventory.sh \
  --exclude glvnd --exclude vulkan-loader
```

1. 共 77 个 library package。
2. 54 个 package 带有已经验证的 all-tests 标记，占 70.13%。
3. package 目录包含 97 个 production shared object。
4. all-tests package 包含其中 63 个，占 64.95%。
5. clean-run workspace 中没有缺失的 package 目录。

## 顺序批处理 runner

批处理顺序执行已经验证的 all-tests 集合，并在 `.work/evaluations/1-libs-batch/verified` 保存控制器日志和单库状态。库失败会被记录，但不会阻止后续库。重复命令会跳过成功库，并重试失败、中断或待运行的库：

```bash
./evaluations/1-libs/run-all.sh --verbose
```

仅在需要时覆盖仓库相对 devkit：

```bash
LORELEI_DEVKIT=/path/to/devkit ./evaluations/1-libs/run-all.sh --verbose
```

交互终端把最近完成的三个结果、当前配方和总进度固定在底部，测试输出在其上方滚动。重定向时自动使用纯文本。`--plain` 显式关闭终端显示，`--verbose` 将 verbose 模式传入每个单库 runner，`--restart` 归档控制器状态并重新开始已验证集合，同时保留只追加的单库结果。`--all` 选择所有真实库配方，包括有明确排除项的配方，但仍排除合成 `breakdown-test` 包。
