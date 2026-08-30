#!/usr/bin/env python3
"""Plot normalized CLI execution time from overall.csv."""

import argparse
import csv
import pathlib

import matplotlib.pyplot as plt
import numpy as np


LANES = ["qemu-hecate", "blink-hecate", "box64-hecate", "fex-hecate", "box64", "qemu", "blink", "fex"]
LABELS = {
    "ffmpeg-fdk-aac": "fdk-aac",
    "ffmpeg-mp3lame": "mp3lame",
    "ffmpeg-vorbis": "ogg/vorbis",
    "ffmpeg-x264": "x264",
}


def main() -> None:
    repo = pathlib.Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, default=repo / "evaluations/paper-data/overall.csv")
    parser.add_argument("--output", type=pathlib.Path, default=repo / ".work/paper-figures/6-overall.pdf")
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()
    rows = list(csv.DictReader(args.csv.open(newline="")))
    workloads = list(dict.fromkeys(row["workload"] for row in rows))
    values = {(row["workload"], row["lane"]): row for row in rows}

    plt.rcParams.update({"font.family": "serif", "font.size": 10})
    fig, ax = plt.subplots(figsize=(11.5, 4.6))
    x = np.arange(len(workloads))
    width = 0.105
    colors = plt.cm.Set3(np.linspace(0, 1, len(LANES)))
    cap = 5.0
    for index, lane in enumerate(LANES):
        heights = []
        labels = []
        for workload in workloads:
            row = values.get((workload, lane), {})
            raw = row.get("normalized_time", "")
            value = float(raw) if raw else np.nan
            if row.get("status") == "excluded":
                heights.append(cap)
                labels.append(">20x")
            elif np.isfinite(value):
                heights.append(min(value, cap))
                labels.append(f"{value:.2f}")
            else:
                heights.append(np.nan)
                labels.append("")
        xpos = x + (index - (len(LANES) - 1) / 2) * width
        bars = ax.bar(xpos, heights, width, label=lane, color=colors[index], edgecolor="black", linewidth=0.6)
        for bar, label in zip(bars, labels):
            if label:
                ax.text(bar.get_x() + bar.get_width() / 2, min(bar.get_height() + 0.08, 4.92), label,
                        ha="center", va="bottom", rotation=90, fontsize=7)

    for workload_index, workload in enumerate(workloads):
        missing = sum(values.get((workload, lane), {}).get("status") == "missing" for lane in LANES)
        if missing:
            ax.text(x[workload_index], 0.05, f"{missing} missing", ha="center", va="bottom", fontsize=7, rotation=90)
    ax.axhline(1, color="firebrick", linestyle="--", linewidth=1)
    ax.set_ylim(0, cap)
    ax.set_ylabel("Normalized time")
    ax.set_xticks(x)
    ax.set_xticklabels([LABELS.get(name, name) for name in workloads])
    ax.grid(axis="y", alpha=0.25)
    ax.legend(ncol=4, loc="lower center", bbox_to_anchor=(0.5, 1.01), frameon=False)
    fig.tight_layout()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, bbox_inches="tight")
    if args.show:
        plt.show()


if __name__ == "__main__":
    main()
