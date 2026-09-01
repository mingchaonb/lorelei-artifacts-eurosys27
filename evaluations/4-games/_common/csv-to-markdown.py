#!/usr/bin/env python3
"""Render a small CSV file as a GitHub-flavored Markdown table."""

from __future__ import annotations

import csv
import pathlib
import sys


PERCENT_COLUMNS = {"box64_coverage", "hecate_coverage"}


def display_cell(header: str, cell: str) -> str:
    if header in PERCENT_COLUMNS and cell:
        try:
            return f"{float(cell):.2%}"
        except ValueError:
            pass
    return cell.replace("|", "\\|").replace("\n", " ")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} INPUT.csv")
    path = pathlib.Path(sys.argv[1])
    with path.open(newline="") as stream:
        reader = csv.reader(stream)
        rows = list(reader)
    if not rows:
        raise SystemExit("CSV is empty")
    title = "Overall performance" if path.stem == "overall" else path.stem.replace("-", " ").replace("_", " ").title()
    print(f"## {title}")
    print()
    print("| " + " | ".join(rows[0]) + " |")
    print("| " + " | ".join("---" for _ in rows[0]) + " |")
    for row in rows[1:]:
        escaped = [display_cell(header, cell) for header, cell in zip(rows[0], row)]
        print("| " + " | ".join(escaped) + " |")


if __name__ == "__main__":
    main()
