# 库正确性验证

[English](README.md)

本组验证 selected library 的公开 C ABI 和 Lorelei 边界机制。每个配方从固定的官方上游版本构建 native AArch64 与 x86-64 guest package，并对比 native 与 Hecate 两条结果路径。

## 1. 正确性声明

对于标题带 `[ALL TESTS PASSED]` 的 package，本 artifact 声明：

1. 当前 shared-library 配置能够发现的上游测试已经安装到 vcpkg package。
2. 属于目标公开 C ABI 且未明确排除的测试全部执行。
3. 相同上游版本的 native AArch64 与 Hecate x86-64 路径均通过。
4. 测试只从安装 prefix 运行，不在运行阶段从 source tree 重新构建。

该声明不扩展到：

- 其他未记录的 build configuration。
- static-only 或 private ABI 测试。
- 原子操作、锁和 contention semantics。
- signal delivery 与 signal-handler 行为。
- 真实 audio、video、input、haptic 或 hotplug device。
- fuzz、sanitizer、stress 和 source-coverage campaign。
- 超出 AE 时间预算的长时间测试。

## 2. 当前覆盖

2026 年 8 月 30 日的完整安装 audit 为：

| 统计对象 | 需要验证 | 完整通过上游测试 | 比例 |
|---|---:|---:|---:|
| library package | 79 | 54 | 68.35% |
| production shared object | 97 | 63 | 64.95% |

统计规则为：

- 合成 `breakdown-test` prerequisite 不计作 library package。
- shared object 只统计 package 内真实 production ELF，不重复计算 `.so` symlink。
- `glvnd` 与 `vulkan-loader` 使用 Ubuntu 系统 DSO，因此计入 package 数量，但不增加 package 内 DSO 数量。
- all-tests 数量只由 README 第一行的 `[ALL TESTS PASSED]` 标记决定。

重新计算 inventory：

```bash
./evaluations/1-libs/_common/summarize-library-inventory.sh
```

## 3. 执行路径

每个 library 只产生两条正确性结果路径：

1. native
   - 运行安装后的 AArch64 上游测试。
   - 链接安装后的 native AArch64 共享库。
2. Hecate
   - 运行安装后的 x86-64 上游测试。
   - 通过生成的 thunk 调用 AArch64 host 共享库。

library 配方不运行纯 QEMU full-emulation lane。

Hecate library 使用以下机制之一：

1. TLC Only
   - TLC 生成 guest 与 host thunk。
   - 不运行 LoreHLR，也不加载 HLR extension。
   - callback 可由 TLC 生成的 replacement 处理。
2. TLC + HLR
   - HLR 从最终 host compilation database 重写 production shared-library closure。
   - TLC callback replacement 必须关闭。
   - callback、CCG 与 FDG 由 HLR 和对应 runtime extension 处理。
   - 经过审查的 HLR 后 patch 只处理生成代码无法表达的构建或 host 内部 pointer 适配。

## 4. 安装

一次安装全部 library 测试 package：

```bash
./evaluations/install-libs.sh
```

该命令会：

1. 依次调用每个 library 的 `run.sh --install-only`。
2. 通过仓库内的 vcpkg overlay 获取固定上游源码。
3. 构建 native、guest 和适用的 Hecate package。
4. 将上游测试安装到 `tools/<port>/upstream-tests/`。
5. 复用已有 download、build 和 package cache。
6. 在某个 library 失败后继续安装后续 library。

只安装单个 library：

```bash
./evaluations/1-libs/sdl2/run.sh --install-only
```

## 5. 运行全部测试

运行已经验证为完整通过的 54 个 package：

```bash
./evaluations/1-libs/run-all.sh --verbose
```

运行除合成 `breakdown-test` 外的全部 79 个 library package：

```bash
./evaluations/1-libs/run-all.sh --all --verbose
```

两种批处理都遵循以下规则：

- 单库失败后继续运行后续 library。
- 控制器状态保存在 `.work/evaluations/1-libs-batch/`。
- 重复同一命令时跳过成功项。
- 失败、中断和待运行项会被重新尝试。
- `--restart` 归档旧控制器状态并重新开始。
- `--plain` 关闭固定在终端底部的进度显示。
- 交互终端显示最近完成的 3 个结果、当前 library 和总进度。

`--all` 包含以下 package：

- 有明确上游测试排除项的 package。
- 只提供定向 public-API workload 的 package。
- 当前不具备完整上游测试安装路径的明确例外，例如 OpenSSL。

它不会把这些 package 自动视为 all-tests 通过。

## 6. 运行单个 library

以 SDL2 为例：

```bash
./evaluations/1-libs/sdl2/run.sh
./evaluations/1-libs/sdl2/run.sh --verbose
./evaluations/1-libs/sdl2/run.sh --install-only
```

常用选项为：

- 默认模式：安装所需 package，生成机制文件并运行 native 与 Hecate 测试。
- `--verbose`：显示 vcpkg、TLC、HLR、build 和测试输出，同时保留原始日志。
- `--install-only`：只准备 package 与机制文件，不运行测试。

某个选项不适用于特定 library 时，其 README 必须明确说明。

## 7. 单库配方契约

每个 `<package>/` 目录必须提供：

1. `README.md` 与 `README.zh-CN.md`
   - 固定上游版本。
   - TLC Only 或 TLC + HLR 路径。
   - 测试数量与预期结果。
   - 明确排除项及原因。
2. `run.sh`
   - 单项评测的唯一公开入口。
   - 从自身位置解析仓库路径。
   - 只使用仓库内 `vcpkg/vcpkg`。
3. vcpkg overlay port
   - 从官方 release 或 commit 获取并校验源码。
   - 从自身 `patches/` 应用版本化 patch。
   - 安装当前配置的上游测试。
4. 结果分类与 audit
   - 保存 native 与 Hecate 原始日志。
   - 保存 source、patch、TLC 与 HLR 身份。
   - 保存配置 LOC 与机器可读汇总。

## 8. 测试分类

单项测试按以下方式分类：

1. `pass`
   - native 与 Hecate 命令都成功。
2. `baseline skip`
   - native 基线在相同配置下失败。
   - Hecate 出现匹配的非零结果。
3. `fail`
   - native 成功而 Hecate 失败。
   - Hecate 测试未执行完整。
   - native 与 Hecate test manifest 不一致。
4. `excluded`
   - 测试在运行前已经由 README 明确列为 scope 外。
   - 排除原因必须是机制边界、配置边界或 AE 时间预算，不能用于隐藏 Hecate 独有失败。

只有所有未排除测试都没有 failure 时，README 标题才能添加 `[ALL TESTS PASSED]`。

## 9. 结果与证据

评审者结果写入：

```text
evaluations/1-libs/<package>/results/<run-id>/
```

每次运行至少保存：

1. native 与 Hecate 的完整原始输出。
2. 每个测试的命令、退出状态与分类。
3. 上游 source、vcpkg port 和 patch 身份。
4. TLC、HLR、runtime 和 emulator 身份。
5. `Desc.h`、`Manifest_guest.cpp` 与 `Manifest_host.cpp` 的配置 LOC 与 SHA-256。
6. 可重新计算通过、跳过和失败数量的机器可读汇总。

以下内容不构成 library 正确性证据：

- 仅成功构建 library。
- 仅成功生成 thunk。
- 仅统计导出 symbol、package 或 DSO 数量。
- `.work/evaluations/` 下的临时 build 与 install 状态。
