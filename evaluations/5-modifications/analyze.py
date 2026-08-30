#!/usr/bin/env python3
"""Measure source modifications with an auditable Lat Box64 selector."""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import re
import subprocess
from collections import deque
from dataclasses import dataclass


SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".h", ".S", ".inc", ".l", ".y"}
LAT_ROOTS = (
    "target/i386/latx/context/",
    "target/i386/latx/wrapper/",
    "target/i386/latx/include/",
)
LAT_INTEGRATION = re.compile(
    r"(?i)(CONFIG_LATX_KZT|latx_kzt|\bkzt[_-]|tunnel_lib|box64context|"
    r"wrappertbbridge|wrappedlib|syscall[_-]tunnel|native[_ -]library)"
)
LOCAL_INCLUDE = re.compile(r'^\s*#\s*include\s*"([^"]+)"', re.MULTILINE)
MESON_SOURCE = re.compile(r"['\"]([^'\"]+\.(?:c|cc|cpp|h|S))['\"]")
LIBNAME = re.compile(r"^\s*#\s*define\s+LIBNAME\s+([A-Za-z0-9_]+)", re.MULTILINE)
HUNK = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
PREPROCESSOR = re.compile(r"^\s*#\s*(if|ifdef|ifndef|endif|else|elif)\b(.*)")


@dataclass
class FileStat:
    project: str
    classification: str
    path: str
    reason: str
    hunks: int
    additions: int
    deletions: int
    physical_lines: int


def git(repo: pathlib.Path, *args: str) -> str:
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True, errors="replace"
    )


def status_map(repo: pathlib.Path, base: str, head: str) -> dict[str, str]:
    result = {}
    output = git(repo, "diff", "--no-renames", "--name-status", base, head)
    for line in output.splitlines():
        fields = line.split("\t")
        result[fields[-1]] = fields[0]
    return result


def file_text(repo: pathlib.Path, revision: str, path: str) -> str:
    return git(repo, "show", f"{revision}:{path}")


def physical_lines(text: str) -> int:
    if not text:
        return 0
    return text.count("\n") + int(not text.endswith("\n"))


def is_source(path: str) -> bool:
    pure = pathlib.PurePosixPath(path)
    return pure.suffix in SOURCE_SUFFIXES or pure.name in {"meson.build", "configure"}


def parse_patch(patch: str) -> tuple[int, int, int, list[dict[str, int]]]:
    additions = 0
    deletions = 0
    hunks = []
    current = None
    for line in patch.splitlines():
        match = HUNK.match(line)
        if match:
            current = {
                "old_start": int(match.group(1)),
                "old_count": int(match.group(2) or 1),
                "new_start": int(match.group(3)),
                "new_count": int(match.group(4) or 1),
                "additions": 0,
                "deletions": 0,
            }
            hunks.append(current)
        elif line.startswith("+") and not line.startswith("+++"):
            additions += 1
            if current is not None:
                current["additions"] += 1
        elif line.startswith("-") and not line.startswith("---"):
            deletions += 1
            if current is not None:
                current["deletions"] += 1
    return len(hunks), additions, deletions, hunks


def resolve_include(repo: pathlib.Path, parent: str, include: str) -> str | None:
    candidates = [
        pathlib.PurePosixPath(parent).parent / include,
        pathlib.PurePosixPath("target/i386/latx/include") / include,
        pathlib.PurePosixPath("target/i386/latx/include/generated") / include,
        pathlib.PurePosixPath("target/i386/latx/context") / include,
        pathlib.PurePosixPath("target/i386/latx/wrapper") / include,
        pathlib.PurePosixPath(include),
    ]
    for candidate in candidates:
        path = candidate.as_posix()
        if (repo / path).is_file():
            return path
    return None


def lat_feature_blocks(text: str) -> list[dict[str, int]]:
    """Find current source blocks that implement KZT integration.

    Whole-file diffs are invalid for Lat because its QEMU 6.0 fork also contains
    years of unrelated translator changes. Conditional compilation provides a
    stable boundary for most integration code. Remaining standalone KZT lines are
    grouped when they are at most two source lines apart.
    """
    lines = text.splitlines()
    stack: list[tuple[int, bool]] = []
    ranges: list[tuple[int, int]] = []
    for index, line in enumerate(lines):
        match = PREPROCESSOR.match(line)
        if not match:
            continue
        directive = match.group(1)
        if directive in {"if", "ifdef", "ifndef"}:
            stack.append((index, bool(LAT_INTEGRATION.search(line))))
        elif directive == "endif" and stack:
            start, selected = stack.pop()
            if selected:
                ranges.append((start, index))

    covered = {line for start, end in ranges for line in range(start, end + 1)}
    standalone = [
        index
        for index, line in enumerate(lines)
        if index not in covered and LAT_INTEGRATION.search(line)
    ]
    clusters: list[list[int]] = []
    for index in standalone:
        if not clusters or index > clusters[-1][-1] + 3:
            clusters.append([index])
        else:
            clusters[-1].append(index)
    ranges.extend((cluster[0], cluster[-1]) for cluster in clusters)
    ranges.sort()
    return [
        {
            "old_start": start + 1,
            "old_count": end - start + 1,
            "new_start": start + 1,
            "new_count": end - start + 1,
            "additions": end - start + 1,
            "deletions": 0,
        }
        for start, end in ranges
    ]


def lat_selection(
    repo: pathlib.Path, base: str, head: str, statuses: dict[str, str]
) -> tuple[dict[str, str], dict, dict[str, list[dict[str, int]]]]:
    """Select build-reachable Box64-derived files and QEMU integration files.

    Lat combines a full translator with an embedded Box64 pass-through subsystem.
    Counting all differences from QEMU would therefore be meaningless. The selector
    begins at the embedded Box64 subsystem's Meson source lists, follows local
    includes, expands the wrapper generator's LIBNAME includes, and separately
    selects existing QEMU files whose content contains a KZT integration token.
    """
    reasons: dict[str, str] = {}
    queue: deque[str] = deque()
    meson_files = [
        "target/i386/latx/context/meson.build",
        "target/i386/latx/wrapper/meson.build",
    ]
    for meson in meson_files:
        text = file_text(repo, head, meson)
        reasons[meson] = "embedded Box64 subsystem Meson build root"
        for source in MESON_SOURCE.findall(text):
            path = (pathlib.PurePosixPath(meson).parent / source).as_posix()
            if (repo / path).is_file():
                reasons.setdefault(path, f"listed by {meson}")
                queue.append(path)

    while queue:
        path = queue.popleft()
        text = file_text(repo, head, path)
        includes = list(LOCAL_INCLUDE.findall(text))
        libname = LIBNAME.search(text)
        if libname:
            name = libname.group(1)
            includes.extend(
                [
                    f"wrapped{name}_private.h",
                    f"generated/wrapped{name}defs.h",
                    f"generated/wrapped{name}types.h",
                    f"generated/wrapped{name}undefs.h",
                ]
            )
        for include in includes:
            resolved = resolve_include(repo, path, include)
            if resolved is None or not resolved.startswith(LAT_ROOTS):
                continue
            if statuses.get(resolved) != "A":
                continue
            if resolved not in reasons:
                reasons[resolved] = f"included by {path}"
                queue.append(resolved)

    feature_blocks = {}
    modified_candidates = [path for path, state in statuses.items() if state == "M"]
    for path in modified_candidates:
        if path.startswith(("docs/", "tests/")) or not is_source(path):
            continue
        try:
            text = file_text(repo, head, path)
        except subprocess.CalledProcessError:
            continue
        blocks = lat_feature_blocks(text)
        if blocks:
            reasons[path] = "current KZT conditional or standalone integration block"
            feature_blocks[path] = blocks

    selected = {
        path: reason
        for path, reason in reasons.items()
        if statuses.get(path) in {"A", "M"} and is_source(path)
    }
    audit = {
        "algorithm": "lat-box64-closure-v1",
        "build_roots": meson_files,
        "integration_token_regex": LAT_INTEGRATION.pattern,
        "rules": [
            "Read source files from the two Meson roots that build Lat's embedded Box64 context and wrapper subsystem.",
            "Follow repository-local quoted includes under the LATX context, wrapper, and include roots.",
            "Expand generated wrapper includes from each source file's LIBNAME macro.",
            "Select pre-existing QEMU files by CONFIG_LATX_KZT conditional blocks and standalone KZT integration statements in the pinned source.",
            "Do not use whole-file Lat diffs because the long-lived fork contains unrelated QEMU and translator changes in the same files.",
            "Exclude the unrelated LATX translator, AOT engine, tests, documentation, binaries, and untracked editor files.",
        ],
    }
    return selected, audit, feature_blocks


def complete_selection(statuses: dict[str, str]) -> tuple[dict[str, str], dict]:
    selected = {
        path: "complete pinned feature diff"
        for path, state in statuses.items()
        if state in {"A", "M"} and is_source(path)
    }
    return selected, {
        "algorithm": "complete-diff-v1",
        "rules": ["Count every added or modified source file in the pinned diff."],
    }


def analyze_project(
    project: str, source: dict, repo: pathlib.Path
) -> tuple[list[FileStat], list[dict], dict]:
    base = source["base"]
    head = source["head"]
    statuses = status_map(repo, base, head)
    feature_blocks = {}
    if source["selection"] == "lat-box64-closure":
        selected, audit, feature_blocks = lat_selection(repo, base, head, statuses)
    else:
        selected, audit = complete_selection(statuses)

    file_rows = []
    hunk_rows = []
    for path in sorted(selected):
        classification = "new" if statuses[path] == "A" else "modified"
        text = file_text(repo, head, path)
        if project == "lat" and classification == "modified":
            hunks = feature_blocks[path]
            hunk_count = len(hunks)
            additions = sum(hunk["additions"] for hunk in hunks)
            deletions = 0
        elif project == "lat" and classification == "new":
            hunks = []
            hunk_count = 0
            additions = physical_lines(text)
            deletions = 0
        else:
            patch = git(repo, "diff", "--no-renames", "--unified=0", base, head, "--", path)
            hunk_count, additions, deletions, hunks = parse_patch(patch)
        lines = physical_lines(text) if classification == "new" else 0
        file_rows.append(
            FileStat(
                project,
                classification,
                path,
                selected[path],
                hunk_count,
                additions,
                deletions,
                lines,
            )
        )
        for index, hunk in enumerate(hunks, 1):
            hunk_rows.append(
                {"project": project, "path": path, "hunk": index, **hunk}
            )
    audit.update(
        {
            "project": project,
            "url": source["url"],
            "base": base,
            "head": head,
            "selected_files": len(file_rows),
        }
    )
    return file_rows, hunk_rows, audit


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", required=True, type=pathlib.Path)
    parser.add_argument("--source-root", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()
    sources = json.loads(args.sources.read_text())
    args.output.mkdir(parents=True, exist_ok=True)

    all_files = []
    all_hunks = []
    audits = []
    for project, source in sources.items():
        files, hunks, audit = analyze_project(
            project, source, args.source_root / project
        )
        all_files.extend(files)
        all_hunks.extend(hunks)
        audits.append(audit)

    with (args.output / "files.csv").open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(
            [
                "project",
                "classification",
                "path",
                "selection_reason",
                "hunks",
                "additions",
                "deletions",
                "changed_lines",
                "physical_lines",
            ]
        )
        for row in all_files:
            writer.writerow(
                [
                    row.project,
                    row.classification,
                    row.path,
                    row.reason,
                    row.hunks,
                    row.additions,
                    row.deletions,
                    row.additions + row.deletions,
                    row.physical_lines,
                ]
            )

    if all_hunks:
        with (args.output / "hunks.csv").open("w", newline="") as stream:
            fields = list(all_hunks[0])
            writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(all_hunks)

    with (args.output / "summary.csv").open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(
            [
                "project",
                "modified_files",
                "modified_hunks",
                "modified_added_lines",
                "modified_deleted_lines",
                "modified_changed_lines",
                "new_files",
                "new_file_lines",
                "base",
                "head",
            ]
        )
        for project, source in sources.items():
            modified = [
                row
                for row in all_files
                if row.project == project and row.classification == "modified"
            ]
            new = [
                row
                for row in all_files
                if row.project == project and row.classification == "new"
            ]
            additions = sum(row.additions for row in modified)
            deletions = sum(row.deletions for row in modified)
            writer.writerow(
                [
                    project,
                    len(modified),
                    sum(row.hunks for row in modified),
                    additions,
                    deletions,
                    additions + deletions,
                    len(new),
                    sum(row.physical_lines for row in new),
                    source["base"],
                    source["head"],
                ]
            )

    (args.output / "selection.json").write_text(
        json.dumps({"schema_version": 1, "projects": audits}, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
