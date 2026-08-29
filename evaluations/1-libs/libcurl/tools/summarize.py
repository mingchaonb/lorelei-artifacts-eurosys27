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
    matched = "write:11:hello curl" in output and "total:11 result:0" in output
    lanes[name] = {"exit_status": status, "response_match": matched}
    if status or not matched:
        failures.append(name)

audit = args.run_dir / "generated/targets/curl"
stat = json.loads((audit / "HLR-Stat.json").read_text())
hlr = {
    "translation_units": len(json.loads((audit / "compile_commands.json").read_text())),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
expected = {"translation_units": 183, "ccg_classes": 1, "fdg_classes": 1, "rewritten_files": 4}
if hlr != expected:
    failures.append("hlr-audit-drift")

result = {
    "schema_version": 2,
    "package": "libcurl",
    "version": "8.20.0",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"libcurl evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, fixed response: {'yes' if lanes['native']['response_match'] else 'no'}")
print(f"Hecate, TLC + HLR: exit {lanes['hecate']['exit_status']}, fixed response: {'yes' if lanes['hecate']['response_match'] else 'no'}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
