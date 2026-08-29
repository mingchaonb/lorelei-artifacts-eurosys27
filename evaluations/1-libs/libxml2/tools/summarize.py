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
    matched = "starts=2 ends=2 text_bytes=7" in output
    lanes[name] = {"exit_status": status, "workload_match": matched}
    if status or not matched:
        failures.append(name)

audit = args.run_dir / "generated/targets/xml2"
stat = json.loads((audit / "HLR-Stat.json").read_text())
hlr = {
    "translation_units": len(json.loads((audit / "compile_commands.json").read_text())),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
expected = {"translation_units": 37, "ccg_classes": 23, "fdg_classes": 20, "rewritten_files": 33}
if hlr != expected:
    failures.append("hlr-audit-drift")

result = {
    "schema_version": 2,
    "package": "libxml2",
    "version": "2.15.3",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"libxml2 evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, SAX workload: {'yes' if lanes['native']['workload_match'] else 'no'}")
print(f"Hecate, TLC + HLR: exit {lanes['hecate']['exit_status']}, SAX workload: {'yes' if lanes['hecate']['workload_match'] else 'no'}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
