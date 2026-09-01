#!/usr/bin/env python3
import csv
import json
import pathlib
import statistics
import sys


FPS_UPPER_BOUND = 300.0


def percentile(values, fraction):
    ordered = sorted(values)
    if not ordered:
        return None
    position = (len(ordered) - 1) * fraction
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


output_path, raw_path, mango_summary_path = map(pathlib.Path, sys.argv[1:])
rows = list(csv.reader(raw_path.open(newline="")))
header_index = next(index for index, row in enumerate(rows) if row and row[0] == "fps")
header = rows[header_index]
samples = []
for row in rows[header_index + 1:]:
    if len(row) != len(header):
        continue
    try:
        samples.append(dict(zip(header, map(float, row))))
    except ValueError:
        continue

retained_samples = [sample for sample in samples if sample["fps"] <= FPS_UPPER_BOUND]
ignored_high_fps_samples = len(samples) - len(retained_samples)
fps = [sample["fps"] for sample in retained_samples]
frametime = [sample["frametime"] for sample in retained_samples]
if not fps:
    raise SystemExit(f"MangoHud CSV contains no FPS samples at or below {FPS_UPPER_BOUND:g}")

mango_rows = list(csv.reader(mango_summary_path.open(newline="")))
mango_summary = {}
if len(mango_rows) >= 2:
    mango_summary = dict(zip(mango_rows[0], mango_rows[1]))

data = {
    "schema_version": 1,
    "collector": "MangoHud",
    "raw_csv": raw_path.name,
    "mangohud_summary_csv": mango_summary_path.name,
    "samples": len(retained_samples),
    "raw_samples": len(samples),
    "ignored_high_fps_samples": ignored_high_fps_samples,
    "fps_upper_bound": FPS_UPPER_BOUND,
    "sample_interval_ms": 100,
    "fps": {
        "average": statistics.fmean(fps),
        "minimum": min(fps),
        "maximum": max(fps),
        "median": statistics.median(fps),
        "p01": percentile(fps, 0.01),
        "p99": percentile(fps, 0.99),
    },
    "frametime_ms": {
        "average": statistics.fmean(frametime),
        "median": statistics.median(frametime),
        "p95": percentile(frametime, 0.95),
        "p99": percentile(frametime, 0.99),
    },
    "mangohud_summary": mango_summary,
}
output_path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
