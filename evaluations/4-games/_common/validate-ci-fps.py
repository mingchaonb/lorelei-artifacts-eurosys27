#!/usr/bin/env python3
"""Select and validate the physical-GPU initial-scene FPS rows from a CI run."""

from __future__ import annotations

import csv
import pathlib
import sys


GAMES = ["supertux", "supertuxkart", "assaultcube", "redeclipse", "openarena"]
LANES = ["native", "qemu-hecate", "box64", "box64-hecate"]
NUMERIC_FIELDS = ["fps_mean", "fps_minimum", "fps_maximum", "fps_variance"]
REQUIRED_FPS_LANES = {"native", "qemu-hecate"}
RECORDED_NON_NUMERIC_PREFIXES = (
    "crash:",
    "ran without FPS sample",
    "completed without FPS sample",
)


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit(f"Usage: {sys.argv[0]} INPUT.csv OUTPUT.csv")
    source = pathlib.Path(sys.argv[1])
    destination = pathlib.Path(sys.argv[2])
    with source.open(newline="") as stream:
        indexed = {
            (row["game"], row["lane"]): row for row in csv.DictReader(stream)
        }

    fields = [
        "game",
        "scene",
        "lane",
        "status",
        "physical_gpu",
        "window_sample_count",
        *NUMERIC_FIELDS,
        "result_dir",
        "raw_csv",
    ]
    output_rows = []
    errors = []
    for game in GAMES:
        for lane in LANES:
            row = indexed.get((game, lane), {})
            output = {field: row.get(field, "") for field in fields}
            output.update({"game": game, "scene": "initial", "lane": lane})
            output_rows.append(output)
            if not row:
                errors.append(f"missing row: {game}, {lane}")
                continue
            status = row.get("status", "missing status")
            if status != "measured":
                if lane in REQUIRED_FPS_LANES or not status.startswith(RECORDED_NON_NUMERIC_PREFIXES):
                    errors.append(f"{game}, {lane}: {status}")
                continue
            if row.get("physical_gpu") != "yes":
                errors.append(
                    f"{game}, {lane}: physical_gpu={row.get('physical_gpu', 'missing')}"
                )
            for field in NUMERIC_FIELDS:
                try:
                    float(row[field])
                except (KeyError, TypeError, ValueError):
                    errors.append(f"{game}, {lane}: missing numeric {field}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(output_rows)

    if errors:
        print("CI FPS validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1
    print(f"Validated {len(output_rows)} physical-GPU FPS rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
