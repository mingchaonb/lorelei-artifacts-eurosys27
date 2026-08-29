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
for name in ("native", "hecate"):
    status = int((args.run_dir / f"logs/{name}/exit-status.txt").read_text())
    output = (args.run_dir / f"logs/{name}/wvtest.log").read_text(errors="replace")
    passed = [int(value) for value in re.findall(r"^test (\d{4})\.\.\.pass", output, re.MULTILINE)]
    sequence_match = passed == list(range(1, 165))
    terminal_match = output.rstrip().endswith("all tests pass")
    lanes[name] = {
        "exit_status": status,
        "passed": len(passed),
        "sequence_0001_through_0164": sequence_match,
        "terminal_result": terminal_match,
    }
    if status or not sequence_match or not terminal_match:
        failures.append(name)

audit = args.run_dir / "generated/targets/wavpack"
stat = json.loads((audit / "HLR-Stat.json").read_text())
hlr = {
    "translation_units": len(json.loads((audit / "compile_commands.json").read_text())),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
expected_hlr = {"translation_units": 23, "ccg_classes": 6, "fdg_classes": 3, "rewritten_files": 10}
if hlr != expected_hlr:
    failures.append("hlr-audit-drift")

result = {
    "schema_version": 2,
    "package": "wavpack",
    "version": "5.9.0",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"WavPack evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, {lanes['native']['passed']} passed, terminal result: {'yes' if lanes['native']['terminal_result'] else 'no'}")
print(f"Hecate, TLC + HLR: exit {lanes['hecate']['exit_status']}, {lanes['hecate']['passed']} passed, terminal result: {'yes' if lanes['hecate']['terminal_result'] else 'no'}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
