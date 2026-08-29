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
    counts_match = "counts:1,4" in log and "packet:4:4:01" in log
    lanes[name] = {"exit_status": status, "counts_match": counts_match}
    if status != 0 or not counts_match:
        failures.append(name)
audit = args.run_dir / "generated/targets/pcap"
stat = json.loads((audit / "HLR-Stat.json").read_text())
database = json.loads((audit / "compile_commands.json").read_text())
hlr = {
    "translation_units": len(database),
    "ccg_classes": len(stat["callbackCheckGuardSignatures"]),
    "fdg_classes": len(stat["functionDecayGuardStats"]),
    "rewritten_files": len(stat["filesNeedPatch"]),
}
if hlr != {"translation_units": 19, "ccg_classes": 1, "fdg_classes": 1, "rewritten_files": 4}:
    failures.append("hlr-audit-drift")
result = {
    "schema_version": 2,
    "package": "libpcap",
    "version": "1.10.6",
    "status": "pass" if not failures else "fail",
    "failures": failures,
    "expected": {"packets": 1, "payload_bytes": 4, "first_byte": 1},
    "hlr": hlr,
    "native": lanes["native"],
    "hecate": lanes["hecate"],
}
(args.run_dir / "summary.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(f"libpcap evaluation status: {result['status']}")
print(f"Native: exit {lanes['native']['exit_status']}, expected packet: {'yes' if lanes['native']['counts_match'] else 'no'}")
print(f"Hecate, TLC + HLR: exit {lanes['hecate']['exit_status']}, expected packet: {'yes' if lanes['hecate']['counts_match'] else 'no'}")
print(f"HLR audit: {hlr['translation_units']} translation units, {hlr['ccg_classes']} CCG, {hlr['fdg_classes']} FDG, {hlr['rewritten_files']} rewritten files")
if failures:
    raise SystemExit(1)
