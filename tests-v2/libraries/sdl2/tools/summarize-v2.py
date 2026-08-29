#!/usr/bin/env python3
import argparse
import json
import pathlib
import re


SUMMARY_RE = re.compile(r"Run Summary: Total=(\d+) Passed=(\d+) Failed=(\d+) Skipped=(\d+)")
FILTER_RE = re.compile(r"--filter\s+(\S+)")


def read_status(path: pathlib.Path) -> dict[str, int]:
    return {
        name: int(value)
        for name, value in (line.split("\t", 1) for line in path.read_text().splitlines() if line)
    }


def automation(path: pathlib.Path) -> dict[str, object]:
    text = path.read_text(errors="replace")
    matches = SUMMARY_RE.findall(text)
    if not matches:
        raise SystemExit(f"No SDL automation summary in {path}")
    total, passed, failed, skipped = (int(value) for value in matches[-1])
    return {
        "total": total,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "failure_filters": sorted(set(FILTER_RE.findall(text))),
    }


def classify(native: dict[str, int], transformed: dict[str, int]) -> dict[str, list[str]]:
    result = {"passed": [], "baseline_skip": [], "failed": []}
    for name, native_exit in native.items():
        if name == "testautomation":
            continue
        transformed_exit = transformed.get(name)
        if transformed_exit == 0:
            result["passed"].append(name)
        elif transformed_exit == native_exit and transformed_exit != 124:
            result["baseline_skip"].append(name)
        else:
            result["failed"].append(name)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    native_status = read_status(args.run_dir / "logs/native/status.tsv")
    native_auto = automation(args.run_dir / "logs/native/testautomation.log")
    fields = ("total", "passed", "failed", "skipped", "failure_filters")
    lanes: dict[str, object] = {}
    failures: list[str] = []
    for mode in ("tlc", "hlr"):
        status_path = args.run_dir / f"logs/{mode}/status.tsv"
        if not status_path.exists():
            continue
        status = read_status(status_path)
        auto = automation(args.run_dir / f"logs/{mode}/testautomation.log")
        auto_matches = all(native_auto[field] == auto[field] for field in fields)
        programs = classify(native_status, status)
        callback_log = args.run_dir / f"logs/{mode}/test-callbacks-ae.log"
        callback_passes = len(re.findall(r"^PASS:", callback_log.read_text(errors="replace"), re.MULTILINE))
        lane_failures = list(programs["failed"])
        if not auto_matches:
            lane_failures.insert(0, "testautomation differs from native")
        if lane_failures:
            failures.append(f"{mode}: " + ", ".join(lane_failures))
        lanes[mode] = {
            "status": "pass" if not lane_failures else "fail",
            "automation": auto,
            "automation_native_equivalent": auto_matches,
            "programs": programs,
            "callback_assertions_passed": callback_passes,
        }
    result = {
        "schema_version": 2,
        "package": "sdl2",
        "status": "pass" if not failures else "fail",
        "failures": failures,
        "native": {"automation": native_auto, "status": native_status},
        "lanes": lanes,
        "excluded": ["testatomic", "testlock", "testsem", "torturethread"],
    }
    (args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(f"SDL2 tests-v2 status: {result['status']}")
    for mode, data in lanes.items():
        programs = data["programs"]
        print(f"{mode}: {len(programs['passed'])} passed, {len(programs['baseline_skip'])} baseline skip, {len(programs['failed'])} failed")
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
