#!/usr/bin/env python3
"""Aggregate host-side presentation timestamps into 100 ms FPS samples."""

import csv
import pathlib
import sys


SAMPLE_SECONDS = 0.1


timestamps_path, output_path, summary_path = map(pathlib.Path, sys.argv[1:4])
timestamps = []
for line in timestamps_path.read_text(errors="replace").splitlines():
    try:
        timestamp = float(line)
    except ValueError:
        continue
    if not timestamps or timestamp >= timestamps[-1]:
        timestamps.append(timestamp)

if len(timestamps) < 2:
    raise SystemExit("fewer than two presentation timestamps were recorded")

first = timestamps[0]
last = timestamps[-1]
complete_bins = int((last - first) / SAMPLE_SECONDS)
if complete_bins < 1:
    raise SystemExit("less than one complete FPS interval was recorded")

counts = [0] * complete_bins
for timestamp in timestamps:
    index = int((timestamp - first) / SAMPLE_SECONDS)
    if index < complete_bins:
        counts[index] += 1

output_path.parent.mkdir(parents=True, exist_ok=True)
with output_path.open("w", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow(["fps", "frametime", "elapsed"])
    for index, count in enumerate(counts):
        fps = count / SAMPLE_SECONDS
        frametime = 1000.0 / fps if fps else 1000.0 * SAMPLE_SECONDS
        elapsed_ns = int((index + 1) * SAMPLE_SECONDS * 1_000_000_000)
        writer.writerow([f"{fps:.6f}", f"{frametime:.6f}", elapsed_ns])

duration = complete_bins * SAMPLE_SECONDS
with summary_path.open("w", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow(["frames", "duration", "sample_interval_ms"])
    writer.writerow([sum(counts), f"{duration:.6f}", int(SAMPLE_SECONDS * 1000)])
