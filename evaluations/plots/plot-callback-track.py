#!/usr/bin/env python3
"""Plot callback address-origin checks from callback-track.csv."""

import argparse
import csv
import pathlib

import matplotlib.pyplot as plt
import numpy as np


def main() -> None:
    repo = pathlib.Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=pathlib.Path, default=repo / "evaluations/paper-data/callback-track.csv")
    parser.add_argument("--output", type=pathlib.Path, default=repo / ".work/paper-figures/6-callback-track.pdf")
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()
    rows = list(csv.DictReader(args.csv.open(newline="")))
    systems = list(dict.fromkeys(row["system"] for row in rows))
    measured = [row for row in rows if row["status"] == "measured" and row["median_ns"]]
    components = list(dict.fromkeys(row["component"] for row in measured))
    colors = dict(zip(components, plt.cm.Set2(np.linspace(0, 1, max(1, len(components))))))
    y = np.arange(len(systems))

    plt.rcParams.update({"font.family": "serif", "font.size": 11})
    fig, ax = plt.subplots(figsize=(8.2, 2.8))
    for row_index, system in enumerate(systems):
        left = 0.0
        system_rows = [row for row in measured if row["system"] == system]
        for row in system_rows:
            value = float(row["median_ns"])
            ax.barh(row_index, value, left=left, height=0.5, color=colors[row["component"]],
                    edgecolor="black", linewidth=0.7, alpha=0.8, label=row["component"])
            left += value
        if not system_rows:
            ax.text(0, row_index, "missing measurement", ha="left", va="center", color="firebrick")
        else:
            ax.text(left, row_index, f" {left:.2f} ns", ha="left", va="center")
    handles, labels = ax.get_legend_handles_labels()
    unique = dict(zip(labels, handles))
    ax.legend(unique.values(), unique.keys(), ncol=3, loc="lower center", bbox_to_anchor=(0.5, 1.01))
    ax.set_yticks(y)
    ax.set_yticklabels(systems)
    ax.invert_yaxis()
    ax.set_xlabel("Time (ns)")
    ax.grid(axis="x", alpha=0.25)
    fig.tight_layout()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, bbox_inches="tight")
    if args.show:
        plt.show()


if __name__ == "__main__":
    main()
