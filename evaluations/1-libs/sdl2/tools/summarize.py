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


def automation(path: pathlib.Path, exit_status: int | None) -> dict[str, object]:
    text = path.read_text(errors="replace")
    matches = SUMMARY_RE.findall(text)
    if not matches:
        return {
            "completed": False,
            "exit_status": exit_status,
            "total": None,
            "passed": None,
            "failed": None,
            "skipped": None,
            "failure_filters": [],
        }
    total, passed, failed, skipped = (int(value) for value in matches[-1])
    return {
        "completed": True,
        "exit_status": exit_status,
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
        elif native_exit != 0 and transformed_exit is not None and transformed_exit != 0:
            result["baseline_skip"].append(name)
        else:
            result["failed"].append(name)
    return result


def native_programs(status: dict[str, int]) -> dict[str, list[str]]:
    programs = {name: value for name, value in status.items() if name != "testautomation"}
    return {
        "passed": sorted(name for name, value in programs.items() if value == 0),
        "nonzero": sorted(name for name, value in programs.items() if value != 0),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", type=pathlib.Path, required=True)
    args = parser.parse_args()
    native_status = read_status(args.run_dir / "logs/native/status.tsv")
    native_auto = automation(
        args.run_dir / "logs/native/testautomation.log",
        native_status.get("testautomation"),
    )
    fields = ("total", "passed", "failed", "skipped", "failure_filters")
    failures: list[str] = []
    if not native_auto["completed"]:
        failures.append("native testautomation did not complete")

    hecate_status = read_status(args.run_dir / "logs/hecate/status.tsv")
    hecate_auto = automation(
        args.run_dir / "logs/hecate/testautomation.log",
        hecate_status.get("testautomation"),
    )
    automation_matches = bool(native_auto["completed"] and hecate_auto["completed"]) and all(
        native_auto[field] == hecate_auto[field] for field in fields
    )
    programs = classify(native_status, hecate_status)
    native_program_result = native_programs(native_status)
    callback_log = args.run_dir / "logs/hecate/test-callbacks-ae.log"
    callback_passes = 0
    if callback_log.exists():
        callback_passes = len(re.findall(r"^PASS:", callback_log.read_text(errors="replace"), re.MULTILINE))
    failures.extend(programs["failed"])
    if not hecate_auto["completed"]:
        failures.insert(0, f"Hecate testautomation did not complete, exit {hecate_auto['exit_status']}")
    elif not automation_matches:
        failures.insert(0, "Hecate testautomation differs from native")

    hecate = {
        "status": "pass" if not failures else "fail",
        "label": "Hecate, TLC + HLR",
        "automation": hecate_auto,
        "automation_native_equivalent": automation_matches,
        "programs": programs,
        "callback_assertions_passed": callback_passes,
    }
    result = {
        "schema_version": 2,
        "package": "sdl2",
        "status": "pass" if not failures else "fail",
        "failures": failures,
        "native": {
            "automation": native_auto,
            "programs": native_program_result,
            "status": native_status,
        },
        "hecate": hecate,
        "excluded": ["testatomic", "testlock", "testsem", "testthread", "torturethread"],
    }
    (args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(f"SDL2 evaluation status: {result['status']}")
    print(
        f"Automation native: {native_auto['passed']} passed, {native_auto['failed']} failed, "
        f"{native_auto['skipped']} skipped of {native_auto['total']}"
    )
    print(
        f"Automation Hecate: {hecate_auto['passed']} passed, {hecate_auto['failed']} failed, "
        f"{hecate_auto['skipped']} skipped of {hecate_auto['total']}, "
        f"native equivalent: {'yes' if automation_matches else 'no'}"
    )
    print(
        f"Programs native: {len(native_program_result['passed'])} passed, "
        f"{len(native_program_result['nonzero'])} nonzero"
    )
    print(
        f"Programs Hecate, TLC + HLR: {len(programs['passed'])} passed, "
        f"{len(programs['baseline_skip'])} baseline skip, {len(programs['failed'])} failed"
    )
    if programs["failed"]:
        differences = ", ".join(
            f"{name} (native {native_status.get(name)}, Hecate {hecate_status.get(name)})"
            for name in programs["failed"]
        )
        print(f"Hecate-only failures: {differences}")
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
