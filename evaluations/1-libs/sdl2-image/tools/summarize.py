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
    output = (args.run_dir / f"logs/{name}/image-load.log").read_text(errors="replace")
    matched = "image-load:pass" in output
    fixture_passes = output.count("format-load:pass")
    lanes[name] = {"exit_status": status, "image_load_match": matched, "upstream_fixture_passes": fixture_passes}
    if status or not matched or fixture_passes != 14:
        failures.append(name)

audit = args.run_dir / "generated/targets/SDL2_image"
stat = json.loads((audit / "HLR-Stat.json").read_text())
hlr = {
    "translation_units": len(json.loads((audit / "compile_commands.json").read_text())),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
expected_hlr = {"translation_units": 20, "ccg_classes": 1, "fdg_classes": 1, "rewritten_files": 1}
if hlr != expected_hlr:
    failures.append("hlr-audit-drift")

result = {
    "schema_version": 2,
    "package": "sdl2-image",
    "version": "2.8.12",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"SDL2_image evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, image load: {'yes' if lanes['native']['image_load_match'] else 'no'}, upstream fixtures: {lanes['native']['upstream_fixture_passes']}/14")
print(f"Hecate, TLC + HLR: exit {lanes['hecate']['exit_status']}, image load: {'yes' if lanes['hecate']['image_load_match'] else 'no'}, upstream fixtures: {lanes['hecate']['upstream_fixture_passes']}/14")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
