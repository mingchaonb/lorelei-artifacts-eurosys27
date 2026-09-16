#!/usr/bin/env python3
"""Summarise repeated game FPS runs across repetitions.

evaluations/export-paper-data.py reports one row per (game, lane) taken from
the most recent run, and its fps_variance describes the spread between the
sampling points inside that single ten-second window. That answers how smooth
a frame rate was, not how much it moved between launches, which is what the
paper needs for error bars.

This script reads every run directory for a cell instead, reduces each run to
one average FPS over the same ten-second window, and reports the spread across
those per-run averages.

    python3 evaluations/export-game-fps-runs.py --since 20260916T140000Z

Writes evaluations/paper-data/game-fps-runs.csv, leaving game-fps.csv alone.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import statistics
import sys


REPO = pathlib.Path(__file__).resolve().parent.parent
LANES = ["native", "qemu-hecate", "box64", "box64-hecate"]
GAMES = [
    "assaultcube",
    "openarena",
    "redeclipse",
    "supertux",
    "supertuxkart",
    "hollow-knight",
]
FIELDS = [
    "game",
    "lane",
    "status",
    "run_count",
    "fps_median",
    "fps_min",
    "fps_max",
    "fps_jitter",
    "note",
]


def load_exporter():
    """Reuse the paper exporter's window selection and MangoHud parsing."""
    path = REPO / "evaluations/export-paper-data.py"
    spec = importlib.util.spec_from_file_location("export_paper_data", path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_statistics(exporter, result_dir: pathlib.Path):
    """Reduce one run to (mean FPS, within-window standard deviation).

    Returns None when the run produced no usable window, so that a crashed or
    too-short run is counted as a failure rather than silently skipped.
    """
    raw_path = exporter.game_raw_csv(result_dir)
    if raw_path is None:
        return None
    interval_ms = 100
    summary_path = result_dir / "fps-summary.json"
    if summary_path.is_file():
        try:
            interval_ms = int(
                json.loads(summary_path.read_text()).get("sample_interval_ms", 100)
            )
        except (json.JSONDecodeError, OSError, TypeError, ValueError):
            pass
    try:
        samples = exporter.mangohud_samples(raw_path)
        window = exporter.game_fps_window(samples, interval_ms)
    except (OSError, ValueError):
        return None
    fps = [
        sample["fps"]
        for sample in window
        if sample["fps"] <= exporter.GAME_FPS_UPPER_BOUND
    ]
    if not fps:
        return None
    jitter = statistics.stdev(fps) if len(fps) > 1 else 0.0
    return statistics.fmean(fps), jitter


def lane_runs(game_dir: pathlib.Path, lane: str, since: str | None):
    """Every run directory for one cell, oldest first.

    Directories are named <UTC timestamp>-<lane>, so a lexical sort is also a
    chronological one, and --since compares against the same spelling.
    """
    results = game_dir / "results"
    if not results.is_dir():
        return []
    matches = [
        path
        for path in results.iterdir()
        if path.is_dir() and path.name.endswith(f"-{lane}")
    ]
    if since:
        matches = [path for path in matches if path.name >= f"{since}-"]
    return sorted(matches, key=lambda path: path.name)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--since",
        help="only consider runs whose directory timestamp is at or after this "
        "UTC stamp, for example 20260916T140000Z",
    )
    parser.add_argument(
        "--drop-first",
        action="store_true",
        help="discard the earliest kept run of every cell as a warm-up, so that "
        "a cold shader or JIT translation cache does not enter the statistics",
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=REPO / "evaluations/paper-data/game-fps-runs.csv",
    )
    args = parser.parse_args()

    exporter = load_exporter()
    rows = []
    for game in GAMES:
        game_dir = REPO / "evaluations/4-games" / game
        if not (game_dir / "run.sh").is_file():
            continue
        for lane in LANES:
            row = {field: "" for field in FIELDS}
            row.update({"game": game, "lane": lane, "status": "not_available"})
            if game == "hollow-knight" and lane == "native":
                row["note"] = "no redistributable native package"
                rows.append(row)
                continue

            runs = lane_runs(game_dir, lane, args.since)
            if not runs:
                row["note"] = "no run directories"
                rows.append(row)
                continue

            dropped = ""
            if args.drop_first:
                dropped = runs[0].name
                runs = runs[1:]

            measured = [
                stats
                for stats in (run_statistics(exporter, run) for run in runs)
                if stats is not None
            ]
            failures = len(runs) - len(measured)
            if not measured:
                row["status"] = "failed"
                row["run_count"] = 0
                row["note"] = f"{failures} run(s) produced no usable FPS window"
                rows.append(row)
                continue

            means = [mean for mean, _ in measured]
            jitters = [jitter for _, jitter in measured]
            notes = []
            if dropped:
                notes.append(f"warm-up run {dropped} discarded")
            if failures:
                notes.append(f"{failures} run(s) excluded, no usable FPS window")
            row.update(
                {
                    "status": "measured",
                    "run_count": len(measured),
                    "fps_median": f"{statistics.median(means):.3f}",
                    "fps_min": f"{min(means):.3f}",
                    "fps_max": f"{max(means):.3f}",
                    "fps_jitter": f"{statistics.median(jitters):.3f}",
                    "note": "; ".join(notes),
                }
            )
            rows.append(row)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    exporter.write_csv(args.output, FIELDS, rows)
    print(f"wrote {args.output.relative_to(REPO)}")
    for row in rows:
        print(
            f"  {row['game']:<14} {row['lane']:<13} {row['status']:<14} "
            f"n={row['run_count'] or '-':<3} median={row['fps_median'] or '-'}"
        )


if __name__ == "__main__":
    sys.exit(main())
