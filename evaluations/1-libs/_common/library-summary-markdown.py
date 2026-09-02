#!/usr/bin/env python3
"""Render one library batch as a compact GitHub Actions summary table."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


def integer(value: Any) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int) and value >= 0:
        return value
    return None


def first_integer(*values: Any) -> int | None:
    for value in values:
        number = integer(value)
        if number is not None:
            return number
    return None


def load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return value if isinstance(value, dict) else {}


def lane_passed(summary: dict[str, Any], lane: str, recipe_passed: bool) -> bool:
    value = summary.get(lane)
    if isinstance(value, dict):
        status = value.get("status")
        if status is not None:
            return status == "pass"
        exit_status = value.get("exit_status")
        if exit_status is not None:
            return exit_status == 0
        if integer(value.get("passed")) is not None or integer(value.get("tests_passed")) is not None:
            return recipe_passed

    lanes = summary.get("lanes", summary.get("execution_lanes", []))
    if isinstance(lanes, list):
        normalized = {str(item).lower() for item in lanes}
        if lane == "hecate" and "hecate" in normalized:
            return recipe_passed
        if lane == "native" and "native" in normalized:
            return recipe_passed

    return recipe_passed and summary.get("tests_run") is not False


def lane_count(summary: dict[str, Any], lane: str) -> int | None:
    lane_data = summary.get(lane)
    if not isinstance(lane_data, dict):
        lane_data = {}
    upstream = summary.get("upstream")
    if not isinstance(upstream, dict):
        upstream = {}
    suite = summary.get("upstream_suite")
    if not isinstance(suite, dict):
        suite = {}

    return first_integer(
        lane_data.get("passed"),
        lane_data.get("tests_passed"),
        suite.get(f"{lane}_passed"),
        upstream.get(f"{lane}_passed"),
        suite.get("passed"),
        upstream.get("passed"),
        upstream.get("tests"),
        summary.get("upstream_tests"),
        summary.get("upstream_registered_tests"),
        summary.get("upstream_tests_passed"),
        summary.get("upstream_shared_tests"),
        summary.get("upstream_test_programs"),
        summary.get("successful_checks"),
        summary.get("known_answer_cases"),
        summary.get("tests"),
    )


def result_directory(repo_root: Path, library: str, recorded: str) -> Path | None:
    if not recorded:
        return None
    run_id = Path(recorded).name
    candidate = repo_root / "evaluations" / "1-libs" / library / "results" / run_id
    return candidate if candidate.is_dir() else None


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--batch-summary", type=Path, required=True)
    args = parser.parse_args()

    print("## Library correctness details")
    print()
    if not args.batch_summary.is_file():
        print(f"Library batch summary was not produced: `{args.batch_summary}`")
        return 0

    rows = list(csv.DictReader(args.batch_summary.open(encoding="utf-8"), delimiter="\t"))
    print("| Library | Recipe | Native | Native tests | Hecate | Hecate tests |")
    print("| --- | --- | --- | ---: | --- | ---: |")

    recipe_passes = 0
    native_passes = 0
    hecate_passes = 0
    native_total = 0
    hecate_total = 0
    native_counted = 0
    hecate_counted = 0

    for row in rows:
        library = row.get("library", "unknown")
        recipe_status = row.get("status", "unknown")
        recipe_passed = recipe_status == "pass"
        run_dir = result_directory(args.repo_root, library, row.get("result_dir", ""))
        summary: dict[str, Any] = {}
        if run_dir is not None:
            summary = load_json(run_dir / "summary.json")
            upstream = load_json(run_dir / "upstream-summary.json")
            if upstream:
                summary = {**summary, **upstream}

        native_ok = lane_passed(summary, "native", recipe_passed)
        hecate_ok = lane_passed(summary, "hecate", recipe_passed)
        native_tests = lane_count(summary, "native")
        hecate_tests = lane_count(summary, "hecate")

        recipe_passes += int(recipe_passed)
        native_passes += int(native_ok)
        hecate_passes += int(hecate_ok)
        if native_tests is not None:
            native_total += native_tests
            native_counted += 1
        if hecate_tests is not None:
            hecate_total += hecate_tests
            hecate_counted += 1

        print(
            "| {} | {} | {} | {} | {} | {} |".format(
                markdown_cell(library),
                recipe_status,
                "pass" if native_ok else "fail",
                native_tests if native_tests is not None else "suite",
                "pass" if hecate_ok else "fail",
                hecate_tests if hecate_tests is not None else "suite",
            )
        )

    print()
    print(f"- Recipes: {recipe_passes}/{len(rows)} passed.")
    print(f"- Native lanes: {native_passes}/{len(rows)} passed. Numeric summaries cover {native_counted} recipes and report {native_total} passing test cases or checks.")
    print(f"- Hecate lanes: {hecate_passes}/{len(rows)} passed. Numeric summaries cover {hecate_counted} recipes and report {hecate_total} passing test cases or checks.")
    print('- `suite` means that the recipe recorded a passing upstream suite without a numeric case count.')
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
