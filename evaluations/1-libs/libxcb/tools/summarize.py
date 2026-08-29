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
    log = (args.run_dir / f"logs/{name}/xcb.log").read_text(errors="replace")
    fields = log.strip().split(":")
    counts_match = len(fields) == 6 and fields[:4] == ["xcb", "11", "0", "1"] and fields[4] == "1"
    lanes[name] = {"exit_status": status, "output": log.strip(), "callback_counts_match": counts_match}
    if status != 0 or not counts_match:
        failures.append(name)
audit = args.run_dir / "generated/targets/xcb"
stat = json.loads((audit / "HLR-Stat.json").read_text())
database = json.loads((audit / "compile_commands.json").read_text())
hlr = {
    "translation_units": len(database),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "files_need_patch": len(stat["filesNeedPatch"]),
}
if hlr != {"translation_units": 8, "ccg_classes": 1, "fdg_classes": 0, "files_need_patch": 2}:
    failures.append("hlr-audit-drift")
result = {
    "schema_version": 2,
    "package": "libxcb",
    "version": "1.15",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "expected": {"protocol": "11.0", "closure_callbacks": 1, "guest_callbacks": 1},
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"libxcb evaluation status: {result['status']}")
print(f"Native: {lanes['native']['output']}")
print(f"Hecate, TLC + HLR: {lanes['hecate']['output']}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['files_need_patch']} post-HLR files")
if failures:
    raise SystemExit(1)
