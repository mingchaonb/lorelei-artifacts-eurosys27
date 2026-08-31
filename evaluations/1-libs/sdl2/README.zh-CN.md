# SDL2 2.28.5 验证（TLC + HLR）

[English](README.md)

本配方是 library evaluation 契约的参考实现。仓库级 vcpkg overlay 固定并构建官方 SDL release，配方生成 SDL 与 libc-shim thunk，并在 native 基线和 Hecate 路径运行相同的选定测试。Hecate 是 Lorelei 在匿名投稿中的名称。SDL 路径组合 TLC thunk、HLR 重写和 runtime extension。

## 评审者命令

按 [`../../../vcpkg-overlay/README.zh-CN.md`](../../../vcpkg-overlay/README.zh-CN.md) 初始化仓库内 vcpkg。完整测试需要 Lorelei 工具、两个 HLR runtime extension、QEMU thread hook、x86-64 sysroot 与 release devkit 中的 `bin/qemu-x86_64`。

```bash
./evaluations/1-libs/sdl2/run.sh
```

显示 vcpkg、thunk generation、build 与测试输出并保留相同原始日志：

```bash
./evaluations/1-libs/sdl2/run.sh --verbose
```

安装经 HLR 重写的 host SDL，生成 SDL thunk 与 libc shim，但跳过全部测试编译和执行：

```bash
./evaluations/1-libs/sdl2/run.sh --install-only
```

install-only 模式不要求 QEMU 或 thread hook。它在 `summary.json` 写入安装路径和 `tests_run: false`。安装文件保留在 `.work/evaluations/sdl2/`，直到下一次 SDL2 运行替换该可丢弃 workspace。

默认运行把评审者证据写入 `results/<run-id>/`。开发树中的 patched QEMU 尚未安装进 devkit 时可使用：

```bash
QEMU=/path/to/patched/qemu-x86_64 \
  ./evaluations/1-libs/sdl2/run.sh
```

## 包含范围

- SDL automation harness 使用固定 seed 运行全部 301 个注册 case。
- 20 个非交互上游程序覆盖 platform query、filesystem、RWops、iconv、dynamic loading、locale、qsort、resampling、dummy audio、timer、key table、sensor 与自动 YUV conversion。
- `TestCallbacks.c` 直接检查 event filter、event watch、log output、assertion handling、timer callback、thread entry callback 与 allocator FDG call。
- `TestFDG.c` 独立检查返回给 guest 的 host function pointer。

native 与 Hecate 使用相同 SDL dummy audio/video 环境。Hecate 非零结果只有在对应 native 命令也失败时才分类为基线跳过，否则仍是 Hecate failure。

每次运行生成 `generated/configuration-loc.json`，记录 `Desc.h`、`Manifest_guest.cpp` 与 `Manifest_host.cpp` 的 physical、code、comment 和 blank 行数、SHA-256 与总数。Symbols、patch、测试和共享 harness 不计入单库配置指标。

## 排除范围

- `testatomic`、`testlock`、`testsem` 与 `torturethread` 依赖 artifact 不声明修复的模拟原子指令或 contention semantics。
- 上游 `testthread` 最后阶段引发 `SIGTERM`，并从 signal handler 执行 SDL logging、delay、shutdown 与 process exit。thread entry callback 仍由 `TestCallbacks.c` 覆盖，但不扩展到 signal delivery。
- 交互 window、device hotplug、物理 audio/input、haptic device、OpenGL 与 Vulkan 程序不能为 dummy-backend 直通范围提供确定性非交互证据。
- fuzz、sanitizer、stress 与源码 coverage campaign 不属于本配方。

SDL 没有纯 TLC 测试路径。唯一 Hecate 路径用 TLC 生成 thunk，关闭 TLC callback replacement，使用 HLR 重写 host SDL 源码并加载 HLR runtime extension。因此 callback 成功归属于 SDL 选定的完整机制。
