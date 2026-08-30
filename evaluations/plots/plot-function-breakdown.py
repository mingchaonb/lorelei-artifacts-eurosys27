#!/usr/bin/env python3
"""Plot function-call phase timing from function-breakdown.csv."""

import argparse
import csv
import pathlib

import matplotlib.pyplot as plt
import numpy as np


def main() -> None:
    repo = pathlib.Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, default=repo / "evaluations/paper-data/function-breakdown.csv")
    parser.add_argument("--output", type=pathlib.Path, default=repo / ".work/paper-figures/6-func-breakdown.pdf")
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()
    rows = list(csv.DictReader(args.csv.open(newline="")))
    if not rows:
        raise SystemExit(f"No measured rows in {args.csv}")
    cases = list(dict.fromkeys(row["case"] for row in rows))
    components = list(dict.fromkeys(row["component"] for row in rows))
    lookup = {(row["case"], row["component"]): float(row["median_ns"]) for row in rows}
    y = np.arange(len(cases))
    left = np.zeros(len(cases))

    plt.rcParams.update({"font.family": "serif", "font.size": 11})
    fig, ax = plt.subplots(figsize=(8.2, max(2.4, 1.0 + len(cases))))
    colors = ["#2E8B57", "#FBFF00", "#1E90FF", "#FF6347"]
    for index, component in enumerate(components):
        component_values = np.array([lookup[(case, component)] for case in cases])
        bars = ax.barh(y, component_values, left=left, height=0.5, label=component,
                       color=colors[index % len(colors)], edgecolor="black", linewidth=0.7, alpha=0.8)
        for bar, value, start in zip(bars, component_values, left):
            if value >= 1:
                ax.text(start + value / 2, bar.get_y() + bar.get_height() / 2, f"{value:.1f}",
                        ha="center", va="center", fontsize=9)
        left += component_values
    ax.set_yticks(y)
    ax.set_yticklabels(cases)
    ax.invert_yaxis()
    ax.set_xlabel("Time (ns)")
    ax.grid(axis="x", alpha=0.25)
    ax.legend(ncol=2, loc="lower center", bbox_to_anchor=(0.5, 1.01))
    fig.tight_layout()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, bbox_inches="tight")
    if args.show:
        plt.show()


if __name__ == "__main__":
    main()
