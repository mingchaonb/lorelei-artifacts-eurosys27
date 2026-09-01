#!/usr/bin/env python3
"""Render a small CSV file as a GitHub-flavored Markdown table."""

from __future__ import annotations

import csv
import pathlib
import sys


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"Usage: {sys.argv[0]} INPUT.csv")
    path = pathlib.Path(sys.argv[1])
    with path.open(newline="") as stream:
        reader = csv.reader(stream)
        rows = list(reader)
    if not rows:
        raise SystemExit("CSV is empty")
    title = path.stem.replace("-", " ").replace("_", " ").title()
    print(f"## {title}")
    print()
    print("| " + " | ".join(rows[0]) + " |")
    print("| " + " | ".join("---" for _ in rows[0]) + " |")
    for row in rows[1:]:
        escaped = [cell.replace("|", "\\|").replace("\n", " ") for cell in row]
        print("| " + " | ".join(escaped) + " |")


if __name__ == "__main__":
    main()
