#!/usr/bin/env python3
import argparse
import json
import pathlib

parser = argparse.ArgumentParser()
parser.add_argument("--run-dir", required=True, type=pathlib.Path)
args = parser.parse_args()

expected_output = "path=payload.txt bytes=24 opens=1 reads=5 closes=1"
lanes = {}
failures = []
for name in ("native", "hecate"):
    status = int((args.run_dir / f"logs/{name}/exit-status.txt").read_text())
    output = (args.run_dir / f"logs/{name}/callbacks.log").read_text(errors="replace")
    matched = expected_output in output
    lanes[name] = {"exit_status": status, "archive_callback_match": matched}
    if status or not matched:
        failures.append(name)

audit = args.run_dir / "generated/targets/archive"
stat = json.loads((audit / "HLR-Stat.json").read_text())
hlr = {
    "translation_units": len(json.loads((audit / "compile_commands.json").read_text())),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
expected_hlr = {"translation_units": 123, "ccg_classes": 3, "fdg_classes": 3, "rewritten_files": 10}
if hlr != expected_hlr:
    failures.append("hlr-audit-drift")

result = {
    "schema_version": 2,
    "package": "libarchive",
    "version": "3.8.9",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"libarchive evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, archive callbacks: {'yes' if lanes['native']['archive_callback_match'] else 'no'}")
print(f"Hecate, TLC + HLR: exit {lanes['hecate']['exit_status']}, archive callbacks: {'yes' if lanes['hecate']['archive_callback_match'] else 'no'}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
