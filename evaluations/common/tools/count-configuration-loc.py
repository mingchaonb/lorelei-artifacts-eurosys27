#!/usr/bin/env python3
"""Count auditable per-library configuration lines without external tools."""

import argparse
import hashlib
import json
import pathlib


def classify_lines(text: str) -> dict[str, int]:
    physical = blank = comment = code = 0
    in_block_comment = False

    for line in text.splitlines():
        physical += 1
        if not line.strip() and not in_block_comment:
            blank += 1
            continue

        has_code = False
        has_comment = in_block_comment
        quote: str | None = None
        escaped = False
        index = 0
        while index < len(line):
            character = line[index]
            following = line[index + 1] if index + 1 < len(line) else ""

            if in_block_comment:
                has_comment = True
                if character == "*" and following == "/":
                    in_block_comment = False
                    index += 2
                else:
                    index += 1
                continue

            if quote is not None:
                has_code = True
                if escaped:
                    escaped = False
                elif character == "\\":
                    escaped = True
                elif character == quote:
                    quote = None
                index += 1
                continue

            if character in ('"', "'"):
                has_code = True
                quote = character
                index += 1
            elif character == "/" and following == "/":
                has_comment = True
                break
            elif character == "/" and following == "*":
                has_comment = True
                in_block_comment = True
                index += 2
            else:
                if not character.isspace():
                    has_code = True
                index += 1

        if has_code:
            code += 1
        elif has_comment:
            comment += 1
        else:
            blank += 1

    return {
        "physical": physical,
        "code": code,
        "comment": comment,
        "blank": blank,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("files", nargs="+", type=pathlib.Path)
    args = parser.parse_args()

    root = args.root.resolve()
    totals = {"physical": 0, "code": 0, "comment": 0, "blank": 0}
    files: list[dict[str, object]] = []
    for input_path in args.files:
        path = input_path.resolve()
        data = path.read_bytes()
        counts = classify_lines(data.decode("utf-8"))
        for metric, value in counts.items():
            totals[metric] += value
        files.append({
            "path": str(path.relative_to(root)),
            "sha256": hashlib.sha256(data).hexdigest(),
            "lines": counts,
        })

    result = {
        "schema_version": 1,
        "metric": "per-library Lorelei configuration LOC",
        "definitions": {
            "physical": "all physical lines",
            "code": "lines containing a non-comment token",
            "comment": "comment-only lines",
            "blank": "empty or whitespace-only lines",
        },
        "files": files,
        "total": totals,
    }
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
