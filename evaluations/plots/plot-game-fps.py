#!/usr/bin/env python3
"""Plot ARM64 game FPS from game-fps.csv."""

import argparse
import csv
import pathlib

import matplotlib.pyplot as plt
import numpy as np


GAMES = [
    "supertux",
    "supertuxkart",
    "assaultcube",
    "redeclipse",
    "hollow-knight",
    "openarena",
]
GAME_LABELS = {"hollow-knight": "hollowknight"}
LANES = ["qemu-hecate", "native", "box64", "box64-hecate"]
LABELS = {
    "qemu-hecate": "QEMU-Hecate",
    "native": "Native",
    "box64": "Box64",
    "box64-hecate": "Box64-Hecate",
}
COLORS = {
    "qemu-hecate": "#2E8B57",
    "native": "#1E90FF",
    "box64": "#FF6347",
    "box64-hecate": "#E7DA66",
}


def main() -> None:
    repo = pathlib.Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--csv", type=pathlib.Path, default=repo / "evaluations/paper-data/game-fps.csv"
    )
    parser.add_argument(
        "--output", type=pathlib.Path, default=repo / ".work/paper-figures/6-fps-arm64.pdf"
    )
    parser.add_argument("--show", action="store_true")
    args = parser.parse_args()

    rows = list(csv.DictReader(args.csv.open(newline="")))
    present_games = {row["game"] for row in rows}
    games = [game for game in GAMES if game in present_games]
    games.extend(sorted(present_games - set(games)))
    lookup = {(row["game"], row["lane"]): row for row in rows}
    x = np.arange(len(games))
    width = 0.2

    plt.rcParams.update({"font.family": "serif", "font.size": 12})
    fig, ax = plt.subplots(figsize=(6, 3))
    for index, lane in enumerate(LANES):
        means = []
        for game in games:
            row = lookup.get((game, lane), {})
            if row.get("status") != "measured" or not row.get("fps_mean"):
                means.append(0.0)
                continue
            means.append(float(row["fps_mean"]))
        positions = x + (index - (len(LANES) - 1) / 2) * width
        bars = ax.bar(
            positions,
            means,
            width,
            label=LABELS[lane],
            color=COLORS[lane],
            edgecolor="black",
            linewidth=0.8,
            alpha=0.8,
        )
        for bar, value in zip(bars, means):
            if value == 0:
                label = "Not Available"
                y = 4
            else:
                label = str(int(round(value)))
                y = min(value * 0.5, 165) if value > 150 else value + 4
            ax.text(
                bar.get_x() + bar.get_width() / 2,
                y,
                label,
                ha="center",
                va="center" if value > 150 else "bottom",
                rotation=-90,
                fontsize=8,
            )

    ax.set_ylabel("FPS")
    ax.set_xticks(x)
    ax.set_xticklabels([GAME_LABELS.get(game, game) for game in games], fontsize=8)
    ax.set_ylim(0, 180)
    ax.grid(axis="y", alpha=0.3)
    ax.legend(ncol=4, loc="upper center", bbox_to_anchor=(0.5, 1.3), fontsize=8)
    fig.subplots_adjust(left=0.09, right=0.99, bottom=0.18, top=0.76)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output, bbox_inches="tight")
    if args.show:
        plt.show()


if __name__ == "__main__":
    main()
