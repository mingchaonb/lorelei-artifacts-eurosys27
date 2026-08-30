#!/usr/bin/env python3
import argparse
import json
import pathlib
import subprocess


def run(command: list[str]) -> None:
    print("+", subprocess.list2cmdline(command), flush=True)
    subprocess.run(command, check=True)


parser = argparse.ArgumentParser()
parser.add_argument("--devkit", required=True)
parser.add_argument("--source", required=True)
parser.add_argument("--build", required=True)
parser.add_argument("--library", required=True)
parser.add_argument("--port", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()

devkit = pathlib.Path(args.devkit).resolve()
source = pathlib.Path(args.source).resolve()
build = pathlib.Path(args.build).resolve()
port = pathlib.Path(args.port).resolve()
output = pathlib.Path(args.output).resolve()
thunk = output / "thunk-stat"
output.mkdir(parents=True, exist_ok=True)

run([
    str(devkit / "bin/LoreMakeThunk.py"),
    "--name", "SDL",
    "--out", str(thunk),
    "--lib", args.library,
    "--symbols", str(port / "lorelei/Symbols.conf"),
    "--desc", str(port / "lorelei/Desc.h"),
    "--manifest-host", str(port / "lorelei/Manifest_host.cpp"),
    "--manifest-guest", str(port / "lorelei/Manifest_guest.cpp"),
    "--no-callback-replace",
    "--devkit", str(devkit),
    "--keep-intermediates",
    "--",
    f"-I{source / 'include'}",
    f"-I{source / 'include/SDL'}",
])

database = json.loads((build / "compile_commands.json").read_text())
production = (source / "src/SDL12_compat.c").resolve()
sources = sorted({
    str(path)
    for entry in database
    for path in [pathlib.Path(entry["file"]).resolve()]
    if path == production
})
if not sources:
    raise SystemExit(f"SDL 1.2 production source missing from compilation database: {production}")
(output / "hlr-sources.txt").write_text("\n".join(sources) + "\n")
stat = thunk / ".gen/SDL/ThunkStat.json"

run([
    str(devkit / "bin/LoreHLR"), "stat",
    "-s", str(stat),
    "-o", str(output / "HLRStat.json"),
    "-p", str(build),
    *sources,
])
run([
    str(devkit / "bin/LoreHLR"), "batch",
    "-s", str(stat),
    "-o", str(source),
    "-p", str(build),
    *sources,
])
