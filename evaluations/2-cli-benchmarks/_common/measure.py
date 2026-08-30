#!/usr/bin/env python3
"""Run one benchmark lane repeatedly and preserve raw timing evidence."""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import pathlib
import shutil
import shlex
import statistics
import subprocess
import sys
import time


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--result-dir", required=True, type=pathlib.Path)
    parser.add_argument("--lane", required=True)
    parser.add_argument("--repetitions", type=int, default=5)
    parser.add_argument("--timeout", type=float, default=100.0)
    parser.add_argument("--stdin-file", type=pathlib.Path)
    parser.add_argument("--stdout-to-output", action="store_true")
    parser.add_argument("--exclude-nonzero", action="store_true")
    parser.add_argument("--exclusion-reason")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command[:1] == ["--"]:
        args.command = args.command[1:]
    if not args.command:
        parser.error("a command is required after --")
    if args.repetitions < 1:
        parser.error("--repetitions must be positive")

    lane_dir = args.result_dir / "raw" / args.lane
    output_dir = args.result_dir / "outputs" / args.lane
    lane_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    records = []

    for repetition in range(1, args.repetitions + 1):
        output = output_dir / f"run-{repetition}"
        command = [part.replace("{output}", str(output)) for part in args.command]
        stdout_path = lane_dir / f"run-{repetition}.stdout"
        stderr_path = lane_dir / f"run-{repetition}.stderr"
        started = time.monotonic_ns()
        timed_out = False
        with contextlib.ExitStack() as stack:
            if args.stdin_file:
                stdin = stack.enter_context(args.stdin_file.open("rb"))
            else:
                stdin = subprocess.DEVNULL
            if args.stdout_to_output:
                stdout = stack.enter_context(output.open("wb"))
            else:
                stdout = stack.enter_context(stdout_path.open("wb"))
            stderr = stack.enter_context(stderr_path.open("wb"))
            try:
                completed = subprocess.run(
                    command,
                    stdin=stdin,
                    stdout=stdout,
                    stderr=stderr,
                    timeout=args.timeout,
                    check=False,
                )
                status = completed.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                status = 124
        elapsed_ns = time.monotonic_ns() - started
        record = {
            "repetition": repetition,
            "elapsed_seconds": elapsed_ns / 1_000_000_000,
            "exit_status": status,
            "timed_out": timed_out,
            "output": str(output),
        }
        records.append(record)
        print(f"{args.lane} {repetition}/{args.repetitions}: {record['elapsed_seconds']:.6f}s exit={status}", flush=True)
        if timed_out or (status != 0 and args.exclude_nonzero):
            # A timed-out command can leave a partial encoder output behind.
            # It is not valid evidence and must not reach workload validators.
            for partial in output.parent.glob(output.name + "*"):
                if partial.is_dir():
                    shutil.rmtree(partial)
                else:
                    partial.unlink()
        if status != 0:
            break

    successful = [record["elapsed_seconds"] for record in records if record["exit_status"] == 0]
    summary = {
        "schema_version": 1,
        "lane": args.lane,
        "command": args.command,
        "command_shell": shlex.join(args.command),
        "repetitions_requested": args.repetitions,
        "timeout_seconds": args.timeout,
        "stdin_file": str(args.stdin_file) if args.stdin_file else None,
        "stdout_to_output": args.stdout_to_output,
        "status": (
            "pass"
            if len(successful) == args.repetitions
            else "excluded"
            if any(record["timed_out"] for record in records) or args.exclude_nonzero
            else "fail"
        ),
        "runs": records,
    }
    if successful:
        summary["seconds"] = {
            "minimum": min(successful),
            "median": statistics.median(successful),
            "maximum": max(successful),
            "mean": statistics.fmean(successful),
        }
    if summary["status"] == "excluded":
        summary["exclusion_reason"] = (
            args.exclusion_reason
            or "exceeded_20x_native_or_100_second_figure_17_cutoff"
        )
    (args.result_dir / f"{args.lane}.json").write_text(json.dumps(summary, indent=2) + "\n")
    with (args.result_dir / f"{args.lane}.tsv").open("w") as stream:
        stream.write("repetition\telapsed_seconds\texit_status\ttimed_out\n")
        for record in records:
            stream.write(
                f"{record['repetition']}\t{record['elapsed_seconds']:.9f}\t"
                f"{record['exit_status']}\t{str(record['timed_out']).lower()}\n"
            )
    raise SystemExit(0 if summary["status"] in {"pass", "excluded"} else 1)


if __name__ == "__main__":
    main()
