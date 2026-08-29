#!/usr/bin/env python3
import argparse
import json
import pathlib
import re

parser = argparse.ArgumentParser()
parser.add_argument("--run-dir", required=True, type=pathlib.Path)
args = parser.parse_args()

lanes = {}
failures = []
pattern = re.compile(r"effect-calls:(\d+) done-calls:(\d+)")
for name in ("native", "hecate"):
    status = int((args.run_dir / f"logs/{name}/exit-status.txt").read_text())
    output = (args.run_dir / f"logs/{name}/effect.log").read_text(errors="replace")
    match = pattern.search(output)
    effect_calls = int(match.group(1)) if match else 0
    done_calls = int(match.group(2)) if match else 0
    passed = status == 0 and effect_calls > 0 and done_calls == 1
    lanes[name] = {"exit_status": status, "effect_calls": effect_calls, "done_calls": done_calls, "passed": passed}
    if not passed:
        failures.append(name)

audit = args.run_dir / "generated/targets/SDL2_mixer"
stat = json.loads((audit / "HLR-Stat.json").read_text())
hlr = {
    "translation_units": len(json.loads((audit / "compile_commands.json").read_text())),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
expected_hlr = {"translation_units": 26, "ccg_classes": 2, "fdg_classes": 2, "rewritten_files": 3}
if hlr != expected_hlr:
    failures.append("hlr-audit-drift")

result = {
    "schema_version": 2,
    "package": "sdl2-mixer",
    "version": "2.8.2",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"SDL2_mixer evaluation status: {result['status']}")
for name, label in (("native", "Native"), ("hecate", "Hecate, TLC + HLR")):
    lane = lanes[name]
    print(f"{label}: exit {lane['exit_status']}, effect calls {lane['effect_calls']}, done calls {lane['done_calls']}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
