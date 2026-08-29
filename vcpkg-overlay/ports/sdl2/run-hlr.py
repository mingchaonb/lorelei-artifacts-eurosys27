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
parser.add_argument("--common-include", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()

devkit = pathlib.Path(args.devkit).resolve()
source = pathlib.Path(args.source).resolve()
build = pathlib.Path(args.build).resolve()
port = pathlib.Path(args.port).resolve()
common_include = pathlib.Path(args.common_include).resolve()
output = pathlib.Path(args.output).resolve()
thunk = output / "thunk-stat"
output.mkdir(parents=True, exist_ok=True)

run([
    str(devkit / "bin/LoreMakeThunk.py"),
    "--name", "SDL2",
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
    f"-I{build / 'include'}",
    f"-I{build / 'include-config-release/SDL2'}",
    f"-I{common_include}",
])

database_path = build / "compile_commands.json"
database = json.loads(database_path.read_text())
production_root = source / "src"
sources = sorted({
    str(path)
    for entry in database
    for path in [pathlib.Path(entry["file"]).resolve()]
    if path.is_relative_to(production_root)
})
if not sources:
    raise SystemExit(f"No production translation units found below {production_root}")
(output / "hlr-sources.txt").write_text("\n".join(sources) + "\n")
stat = thunk / ".gen/SDL2/ThunkStat.json"

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
