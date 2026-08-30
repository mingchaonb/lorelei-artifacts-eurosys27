#!/usr/bin/env python3
import argparse
import json
import pathlib
import re


def names(path, pattern):
    text = path.read_text(errors="replace")
    found = set()
    for match in re.finditer(pattern, text, re.MULTILINE):
        name = match.group(1).strip()
        if not name.startswith("fate-"):
            name = "fate-" + name
        found.add(name)
    return found


parser = argparse.ArgumentParser()
parser.add_argument("--run-dir", required=True, type=pathlib.Path)
args = parser.parse_args()
run_dir = args.run_dir

native_manifest = set((run_dir / "generated/fate-native.txt").read_text().split())
hecate_manifest = set((run_dir / "generated/fate-hecate.txt").read_text().split())
native_log = run_dir / "logs/native/fate.log"
hecate_log = run_dir / "logs/hecate/fate.log"
native_failed = names(native_log, r"^Test\s+(.+?)\s+failed\.")
hecate_failed = names(hecate_log, r"^Test\s+(.+?)\s+failed\.")
native_executed = names(native_log, r"^TEST\s+(.+?)\s*$")
hecate_executed = names(hecate_log, r"^TEST\s+(.+?)\s*$")

manifest_match = native_manifest == hecate_manifest
baseline_skips = native_failed & hecate_failed
hecate_only_failures = hecate_failed - native_failed
native_only_failures = native_failed - hecate_failed
missing_native = native_manifest - native_executed
missing_hecate = hecate_manifest - hecate_executed

repeat_status = {}
for lane in ("native", "hecate"):
    path = run_dir / f"logs/{lane}/api-threadmessage-status.tsv"
    values = []
    if path.exists():
        for line in path.read_text().splitlines():
            _, status = line.split("\t", 1)
            values.append(int(status))
    repeat_status[lane] = values
repeats_pass = all(len(values) == 5 and all(value == 0 for value in values) for values in repeat_status.values())

status = "pass"
if not manifest_match or hecate_only_failures or missing_native or missing_hecate or not repeats_pass:
    status = "fail"

summary = {
    "schema_version": 2,
    "package": "ffmpeg",
    "release": "7.1.5",
    "mechanism": "TLC + HLR",
    "status": status,
    "manifest_match": manifest_match,
    "registered_tests": len(native_manifest),
    "native": {
        "passed": len(native_manifest - native_failed),
        "failed": len(native_failed),
        "not_executed": sorted(missing_native),
        "failures": sorted(native_failed),
    },
    "hecate": {
        "passed": len(hecate_manifest - baseline_skips - hecate_only_failures),
        "baseline_skips": len(baseline_skips),
        "failed": len(hecate_only_failures),
        "not_executed": sorted(missing_hecate),
        "failures": sorted(hecate_only_failures),
    },
    "native_only_failures": sorted(native_only_failures),
    "api_threadmessage_repetitions": repeat_status,
}
(run_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

print(f"FFmpeg evaluation status: {status}")
print(f"Native: {summary['native']['passed']} passed, {summary['native']['failed']} baseline failures")
print(f"Hecate, TLC + HLR: {summary['hecate']['passed']} passed, {summary['hecate']['baseline_skips']} baseline skips, {summary['hecate']['failed']} failed")
raise SystemExit(status != "pass")
