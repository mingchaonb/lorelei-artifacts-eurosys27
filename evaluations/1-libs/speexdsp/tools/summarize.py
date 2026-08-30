#!/usr/bin/env python3
import argparse
import json
import pathlib
import sys


parser = argparse.ArgumentParser()
parser.add_argument("--run-dir", required=True, type=pathlib.Path)
parser.add_argument("--runtime", required=True, type=pathlib.Path)
args = parser.parse_args()

names = ["testdenoise", "testecho", "testjitter", "testresample", "testresample2"]


def statuses(lane):
    rows = {}
    path = args.run_dir / "logs" / lane / "status.tsv"
    for line in path.read_text().splitlines():
        name, status = line.split("\t")
        rows[name] = int(status)
    return rows


native = statuses("native")
hecate = statuses("hecate")
errors = []
for name in names:
    if native.get(name) != 0:
        errors.append(f"native {name} exit={native.get(name)}")
    if hecate.get(name) != 0:
        errors.append(f"hecate {name} exit={hecate.get(name)}")

for name, suffix in (("testdenoise", ".bin"), ("testecho", ".bin"), ("testjitter", ".txt"), ("testresample", ".bin")):
    left = (args.runtime / "native" / f"{name}{suffix}").read_bytes()
    right = (args.runtime / "hecate" / f"{name}{suffix}").read_bytes()
    if not left:
        errors.append(f"{name} produced empty output")
    if left != right:
        errors.append(f"{name} native and Hecate outputs differ")

jitter = (args.runtime / "native" / "testjitter.txt").read_text(errors="replace")
if "failed" in jitter.lower() or "Frozen sender: Jitter" not in jitter:
    errors.append("testjitter did not report successful frozen-sender recovery")

native_sweep = args.runtime / "native" / "testresample2.bin"
hecate_sweep = args.runtime / "hecate" / "testresample2.bin"
if native_sweep.stat().st_size == 0 or native_sweep.stat().st_size != hecate_sweep.stat().st_size:
    errors.append("testresample2 output sizes are empty or asymmetric")

data = {
    "schema_version": 2,
    "package": "speexdsp",
    "release": "1.2.1",
    "status": "pass" if not errors else "fail",
    "test_scope": "all five upstream noinst test programs",
    "tests_run": True,
    "tests_passed": 5 if not errors else 5 - len(errors),
    "tests_failed": len(errors),
    "native": {"passed": sum(value == 0 for value in native.values()), "total": 5},
    "hecate": {"passed": sum(value == 0 for value in hecate.values()), "total": 5},
    "mechanism": "TLC Only",
    "pure_qemu_run": False,
    "errors": errors,
}
(args.run_dir / "summary.json").write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    sys.exit(1)
