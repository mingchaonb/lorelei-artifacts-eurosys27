# QEMU 修改量统计

[English](README.md)

本组生成论文修改量表对应的可审计 CSV。它比较 Lat 中嵌入的 Box64 library pass-through、Risotto native-library feature 和 Hecate 上游 QEMU syscall-filter API。脚本只分析源码，不编译或执行模拟器。

## 1. 一键运行

从任意目录运行：

```bash
/absolute/path/to/eurosys-lorelei-artifacts/evaluations/5-modifications/run.sh
```

脚本会在 `.work/evaluations/modifications/sources/` 复用源码 clone，拉取 `sources.json` 中固定的 revision，再把结果写入新的 `results/<UTC timestamp>/`。后续运行不会重新 clone 已存在的仓库。

## 2. 固定比较范围

| 项目 | 比较范围 | 选择方法 |
|---|---|---|
| Lat | QEMU 6.0.0 到固定 Lat revision | Box64/KZT build dependency closure 加 QEMU integration block |
| Risotto | initial native-library infrastructure 的前一个 revision 到 LID parser revision | 完整 feature commit range |
| Hecate | upstream syscall-filter commit 的父 revision 到该 commit | 完整单 commit diff |

Risotto 的范围只包含 native-library feature，不混入同一分支上的 memory-mapping、fence optimization 和 native CAS 工作。Hecate 使用已经合入上游 QEMU 的固定 commit。

## 3. Lat 选择算法

Lat 同时包含完整的 LATX translator 和嵌入的 Box64 pass-through 模块。直接计算 Lat 与 QEMU 的整个仓库 diff 会把 translator、AOT、指令优化、测试和多年维护改动错误计入 Box64，因此脚本执行以下选择：

1. 从 `target/i386/latx/context/meson.build` 和 `target/i386/latx/wrapper/meson.build` 开始。这两个 build root 描述 Lat 中嵌入的 Box64 context 与 wrapper 子系统。
2. 递归解析 repository-local quoted include。
3. 根据每个 wrapper source 的 `LIBNAME` 展开 `wrapped<name>_private.h` 和三个 `generated/wrapped<name>*.h` include。
4. 新文件只统计该闭包内可构建的 C、C++、assembly、lexer、parser、header 和 Meson source file。
5. 对已有 QEMU 文件，不使用整个文件的历史 diff。脚本只统计当前源码中的 `CONFIG_LATX_KZT` 条件块和独立 KZT integration statement。
6. 排除无关 translator、AOT、文档、测试、二进制文件和 editor 临时文件。

`selection.json` 保存完整规则和固定 revision。`files.csv` 为每个入选文件记录原因。`hunks.csv` 为每个修改块记录源码行区间，因此 Lat 的选择可以逐项复核。

## 4. 指标口径

1. `modified_files`
   - 至少包含一个被选 integration block 的已有文件数。
2. `modified_hunks`
   - Risotto 与 Hecate 使用 zero-context Git diff hunk 数。
   - Lat 使用源码感知的 KZT conditional 或 standalone block 数。
3. `modified_added_lines` 与 `modified_deleted_lines`
   - Risotto 与 Hecate为 Git diff 中的新增与删除行。
   - Lat 的新增行表示当前入选 integration block 的物理行数，删除行为 0，因为长期 fork 不存在可把其他 LATX 变化排除掉的 KZT-off 历史版本。
4. `modified_changed_lines`
   - 前两列之和。
5. `new_files`
   - 在 base 不存在、在选择范围内新增的 source file 数。
6. `new_file_lines`
   - 新文件当前 revision 的物理行数，包含空行和注释。

这套口径明确展示 Lat 长期 fork 的限制，不把不可比较的整文件 diff 包装成精确的 Box64 修改量。

## 5. 输出

每次运行生成：

- `summary.csv`，论文表格使用的一行一个项目汇总。
- `files.csv`，一行一个文件的分类、选择原因和行数。
- `hunks.csv`，一行一个修改块的位置和行数。
- `selection.json`，revision、算法版本和规则。
- `environment.txt`，运行时间、系统、Git 版本和脚本校验和。
