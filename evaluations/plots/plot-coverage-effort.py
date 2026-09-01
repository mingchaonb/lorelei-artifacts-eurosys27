#!/usr/bin/env python3
"""Plot current wrapper coverage and manual configuration LOC from CSV."""

import argparse
import csv
import pathlib

import matplotlib.pyplot as plt
import numpy as np


def main() -> None:
    repo = pathlib.Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, default=repo / "evaluations/paper-data/coverage-effort.csv")
    parser.add_argument("--output", type=pathlib.Path, default=repo / ".work/paper-figures/6-coverage-effort.pdf")
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()
    all_rows = list(csv.DictReader(args.csv.open(newline="")))
    rows = [row for row in all_rows if row["status"] == "measured"]
    if not rows:
        raise SystemExit(f"No measured rows in {args.csv}")
    names = [row["library"] for row in rows]
    x = np.arange(len(rows))
    width = 0.32
    box_loc = np.array([float(row["box64_manual_loc"]) for row in rows])
    hecate_loc = np.array([float(row["hecate_manual_loc"]) for row in rows])
    box_cov = np.array([float(row["box64_coverage"]) for row in rows])
    hecate_cov = np.array([float(row["hecate_coverage"]) for row in rows])

    plt.rcParams.update({"font.family": "serif", "font.size": 10})
    fig, ax = plt.subplots(figsize=(13.8, 5.2))
    coverage = ax.twinx()
    ax.bar(x - width / 2, box_loc, width, label="Box64 LOC", color="#FF6347", edgecolor="black", alpha=0.8)
    ax.bar(x + width / 2, hecate_loc, width, label="Hecate LOC", color="#2E8B57", edgecolor="black", alpha=0.8)
    coverage.plot(x - width / 2, box_cov, "o", label="Box64 coverage", color="#8B0000")
    coverage.plot(x + width / 2, hecate_cov, "^", label="Hecate coverage", color="#006400")
    ax.set_xticks(x)
    ax.set_xticklabels(names, rotation=38, ha="right", rotation_mode="anchor")
    ax.set_ylabel("Manual code lines")
    coverage.set_ylabel("Exported-function coverage")
    coverage.set_ylim(0, 1.05)
    coverage.set_yticks([0, 0.25, 0.5, 0.75, 1.0], ["0%", "25%", "50%", "75%", "100%"])
    handles1, labels1 = ax.get_legend_handles_labels()
    handles2, labels2 = coverage.get_legend_handles_labels()
    ax.legend(handles1 + handles2, labels1 + labels2, ncol=2, loc="lower center", bbox_to_anchor=(0.5, 1.01))
    missing = [row["library"] for row in all_rows if row["status"] != "measured"]
    if missing:
        fig.text(0.5, 0.01, "Missing prerequisites: " + ", ".join(missing), ha="center", color="firebrick")
    ax.grid(axis="y", alpha=0.25)
    fig.tight_layout(rect=(0, 0.02, 1, 1))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, bbox_inches="tight")
    if args.show:
        plt.show()


if __name__ == "__main__":
    main()
