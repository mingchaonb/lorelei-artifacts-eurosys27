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
    log = (args.run_dir / f"logs/{name}/callbacks.log").read_text(errors="replace")
    counts_match = "counts:2,2,7" in log
    lanes[name] = {"exit_status": status, "counts_match": counts_match}
    if status != 0 or not counts_match:
        failures.append(name)

audit_dir = args.run_dir / "generated/targets/expat"
hlr_stat = json.loads((audit_dir / "HLR-Stat.json").read_text())
compile_commands = json.loads((audit_dir / "compile_commands.json").read_text())
hlr = {
    "translation_units": len(compile_commands),
    "ccg_classes": len(hlr_stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(hlr_stat["functionDecayGuardStats"]),
    "rewritten_files": len(hlr_stat["filesNeedPatch"]),
}
expected_hlr = {"translation_units": 7, "ccg_classes": 3, "fdg_classes": 0, "rewritten_files": 1}
if hlr != expected_hlr:
    failures.append("hlr-audit-drift")

result = {
    "schema_version": 2,
    "package": "expat",
    "version": "2.8.2",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "expected": {"starts": 2, "ends": 2, "text_bytes": 7},
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"Expat evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, expected counts: {'yes' if lanes['native']['counts_match'] else 'no'}")
print(f"Hecate, TLC + HLR: exit {lanes['hecate']['exit_status']}, expected counts: {'yes' if lanes['hecate']['counts_match'] else 'no'}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten file")
if failures:
    raise SystemExit(1)
