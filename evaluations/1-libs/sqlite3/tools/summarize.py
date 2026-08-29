#!/usr/bin/env python3
import argparse
import json
import pathlib

parser = argparse.ArgumentParser()
parser.add_argument("--run-dir", required=True, type=pathlib.Path)
args = parser.parse_args()

lanes = {}
failures = []
for name in ("native", "hecate"):
    status = int((args.run_dir / f"logs/{name}/exit-status.txt").read_text())
    output = (args.run_dir / f"logs/{name}/callbacks.log").read_text(errors="replace")
    matched = "rows=1 updates=1 result=42" in output
    lanes[name] = {"exit_status": status, "workload_match": matched}
    if status or not matched:
        failures.append(name)

audit = args.run_dir / "generated/targets/sqlite3"
stat = json.loads((audit / "HLR-Stat.json").read_text())
hlr = {
    "translation_units": len(json.loads((audit / "compile_commands.json").read_text())),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
expected = {"translation_units": 1, "ccg_classes": 5, "fdg_classes": 4, "rewritten_files": 1}
if hlr != expected:
    failures.append("hlr-audit-drift")

result = {
    "schema_version": 2,
    "package": "sqlite3",
    "version": "3.53.4",
    "source_form": "official release amalgamation",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"SQLite evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, callback workload: {'yes' if lanes['native']['workload_match'] else 'no'}")
print(f"Hecate, TLC + HLR: exit {lanes['hecate']['exit_status']}, callback workload: {'yes' if lanes['hecate']['workload_match'] else 'no'}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
