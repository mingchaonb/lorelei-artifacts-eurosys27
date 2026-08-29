#!/usr/bin/env python3
import argparse
import json
import pathlib
import re

parser = argparse.ArgumentParser()
parser.add_argument("--run-dir", required=True, type=pathlib.Path)
args = parser.parse_args()

failures = []
lanes = {}
pattern = re.compile(r"text-size:(\d+)x(\d+)")
for name in ("native", "hecate"):
    status = int((args.run_dir / f"logs/{name}/exit-status.txt").read_text())
    output = (args.run_dir / f"logs/{name}/upstream.log").read_text(errors="replace")
    match = pattern.search(output)
    size = [int(match.group(1)), int(match.group(2))] if match else None
    lanes[name] = {"exit_status": status, "text_size": size}
    if status or size is None:
        failures.append(name)
if lanes["native"]["text_size"] != lanes["hecate"]["text_size"]:
    failures.append("output-mismatch")

audit = args.run_dir / "generated/targets/SDL2_ttf"
stat = json.loads((audit / "HLR-Stat.json").read_text())
hlr = {
    "translation_units": len(json.loads((audit / "compile_commands.json").read_text())),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
expected = {"translation_units": 1, "ccg_classes": 0, "fdg_classes": 0, "rewritten_files": 0}
if hlr != expected:
    failures.append("hlr-audit-drift")

result = {"schema_version": 2, "package": "sdl2-ttf", "version": "2.24.0", "status": "pass" if not failures else "fail", "failures": failures, "hlr": hlr, "native": lanes["native"], "hecate": lanes["hecate"]}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"SDL2_ttf evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, size {lanes['native']['text_size']}")
print(f"Hecate: exit {lanes['hecate']['exit_status']}, size {lanes['hecate']['text_size']}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
