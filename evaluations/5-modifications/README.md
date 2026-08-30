# QEMU modification statistics

[中文版](README.zh-CN.md)

This group generates auditable CSV data for the paper's modification table. It compares Lat's embedded Box64 library pass-through, Risotto's native-library feature, and the upstream QEMU syscall-filter API used by Hecate. The script performs source analysis only and does not build or execute an emulator.

## 1. One-command run

Run from any working directory:

```bash
/absolute/path/to/eurosys-lorelei-artifacts/evaluations/5-modifications/run.sh
```

The runner reuses source clones under `.work/evaluations/modifications/sources/`, fetches the revisions pinned in `sources.json`, and writes a new `results/<UTC timestamp>/`. Later runs do not clone an existing repository again.

## 2. Pinned comparison ranges

| Project | Comparison range | Selection method |
|---|---|---|
| Lat | QEMU 6.0.0 to the pinned Lat revision | Box64/KZT build dependency closure plus QEMU integration blocks |
| Risotto | Parent of the initial native-library infrastructure revision through the LID parser revision | Complete feature commit range |
| Hecate | Parent of the upstream syscall-filter revision through that revision | Complete single-commit diff |

The Risotto range contains only its native-library feature. It does not mix in the branch's memory-mapping, fence-optimization, or native-CAS work. Hecate uses the pinned commit merged into upstream QEMU.

## 3. Lat selection algorithm

Lat contains both a complete LATX translator and an embedded Box64 pass-through subsystem. A whole-repository Lat-versus-QEMU diff would incorrectly attribute the translator, AOT engine, instruction optimizations, tests, and years of maintenance to Box64. The analyzer therefore applies these rules:

1. Start at `target/i386/latx/context/meson.build` and `target/i386/latx/wrapper/meson.build`, the build roots for Lat's embedded Box64 context and wrapper subsystem.
2. Recursively resolve repository-local quoted includes.
3. Expand `wrapped<name>_private.h` and the three `generated/wrapped<name>*.h` includes from each wrapper source's `LIBNAME` macro.
4. Count new C, C++, assembly, lexer, parser, header, and Meson source files only when they are in this build closure.
5. Do not use a whole-file historical diff for existing QEMU files. Count only `CONFIG_LATX_KZT` conditional blocks and standalone KZT integration statements in the pinned source.
6. Exclude the unrelated translator, AOT engine, documentation, tests, binaries, and editor temporary files.

`selection.json` records the complete rules and pinned revisions. `files.csv` records why every file was selected. `hunks.csv` records the source range of every modification block, making the Lat selection reviewable item by item.

## 4. Metric definitions

1. `modified_files`
   - Existing files containing at least one selected integration block.
2. `modified_hunks`
   - Zero-context Git diff hunks for Risotto and Hecate.
   - Source-aware KZT conditional or standalone blocks for Lat.
3. `modified_added_lines` and `modified_deleted_lines`
   - Added and deleted Git diff lines for Risotto and Hecate.
   - For Lat, added lines are the current physical lines in selected integration blocks and deleted lines are zero. The long-lived fork has no KZT-off history that can separate unrelated LATX changes.
4. `modified_changed_lines`
   - Sum of the preceding two columns.
5. `new_files`
   - Selected source files absent from the base revision.
6. `new_file_lines`
   - Physical lines in new files at the pinned revision, including comments and blank lines.

This definition exposes the limitation of analyzing a long-lived Lat fork instead of presenting an incomparable whole-file diff as an exact Box64 modification count.

## 5. Outputs

Each run produces:

- `summary.csv`, one readable table row per project.
- `files.csv`, one row per file with classification, selection reason, and line counts.
- `hunks.csv`, one row per modification block with source positions and line counts.
- `selection.json`, revisions, algorithm version, and rules.
- `environment.txt`, timestamp, system, Git version, and analyzer checksums.
