#!/usr/bin/env python3
import argparse
import json
import pathlib
import shutil
import subprocess


def run(command: list[str]) -> None:
    print("+", subprocess.list2cmdline(command), flush=True)
    subprocess.run(command, check=True)


parser = argparse.ArgumentParser()
parser.add_argument("--devkit", required=True)
parser.add_argument("--source", required=True)
parser.add_argument("--source-root", action="append", required=True)
parser.add_argument("--extra-source", action="append", default=[])
parser.add_argument("--exclude-source", action="append", default=[])
parser.add_argument("--output-contains")
parser.add_argument("--build", required=True)
parser.add_argument("--library", required=True)
parser.add_argument("--port", required=True)
parser.add_argument("--name", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--include", action="append", default=[])
parser.add_argument("--htl-arg", action="append", default=[])
args = parser.parse_args()

devkit = pathlib.Path(args.devkit).resolve()
source = pathlib.Path(args.source).resolve()
source_roots = [pathlib.Path(path).resolve() for path in args.source_root]
extra_sources = {pathlib.Path(path).resolve() for path in args.extra_source}
excluded_sources = {pathlib.Path(path).resolve() for path in args.exclude_source}
build = pathlib.Path(args.build).resolve()
port = pathlib.Path(args.port).resolve()
output = pathlib.Path(args.output).resolve()
thunk = output / "thunk-stat"
output.mkdir(parents=True, exist_ok=True)

thunk_command = [
    str(devkit / "bin/LoreMakeThunk.py"),
    "--name", args.name,
    "--out", str(thunk),
    "--lib", str(pathlib.Path(args.library).resolve()),
    "--symbols", str(port / "lorelei/Symbols.conf"),
    "--desc", str(port / "lorelei/Desc.h"),
    "--no-callback-replace",
    "--devkit", str(devkit),
    "--keep-intermediates",
]
for side in ("host", "guest"):
    manifest = port / f"lorelei/Manifest_{side}.cpp"
    if manifest.exists():
        thunk_command.extend([f"--manifest-{side}", str(manifest)])
for flag in args.htl_arg:
    thunk_command.append(f"--htl-arg={flag}")
thunk_command.append("--")
thunk_command.extend(f"-I{pathlib.Path(path).resolve()}" for path in args.include)
run(thunk_command)

database_path = build / "compile_commands.json"
database = json.loads(database_path.read_text())


def normalize_include_arguments(entry: dict) -> dict:
    """Make directory-relative include paths usable by LoreHLR's batch invocation."""
    arguments = entry.get("arguments")
    if not arguments:
        return entry
    directory = pathlib.Path(entry["directory"])
    source_file = pathlib.Path(entry["file"]).resolve()
    normalized = []
    take_path = False
    for argument in arguments:
        if take_path:
            path = pathlib.Path(argument)
            normalized.append(str((directory / path).resolve()) if not path.is_absolute() else argument)
            take_path = False
            continue
        if argument in ("-I", "-iquote", "-isystem"):
            normalized.append(argument)
            take_path = True
            continue
        matched = False
        for prefix in ("-I", "-iquote", "-isystem"):
            if argument.startswith(prefix) and len(argument) > len(prefix):
                path = pathlib.Path(argument[len(prefix):])
                if not path.is_absolute():
                    argument = prefix + str((directory / path).resolve())
                matched = True
                break
        if not matched and not argument.startswith("-"):
            path = pathlib.Path(argument)
            resolved = path.resolve() if path.is_absolute() else (directory / path).resolve()
            if resolved == source_file:
                argument = str(source_file)
        normalized.append(argument)
    copied = dict(entry)
    copied["arguments"] = normalized
    return copied


database = [normalize_include_arguments(entry) for entry in database]
database_path.write_text(json.dumps(database, indent=2) + "\n")
production_entries = []
for entry in database:
    if args.output_contains and args.output_contains not in entry.get("output", ""):
        continue
    path = pathlib.Path(entry["file"])
    if not path.is_absolute():
        path = pathlib.Path(entry["directory"]) / path
    path = path.resolve()
    if path in excluded_sources:
        continue
    if any(path.is_relative_to(root) for root in source_roots) or path in extra_sources:
        production_entries.append(entry)
sources = sorted({
    str((pathlib.Path(entry["directory"]) / entry["file"]).resolve())
    if not pathlib.Path(entry["file"]).is_absolute()
    else str(pathlib.Path(entry["file"]).resolve())
    for entry in production_entries
})
if not sources:
    raise SystemExit(f"No production translation units found below {source_roots}")
(output / "compile_commands.json").write_text(json.dumps(production_entries, indent=2) + "\n")
(output / "hlr-sources.txt").write_text("\n".join(sources) + "\n")

stat = thunk / f".gen/{args.name}/ThunkStat.json"
shutil.copy2(stat, output / "TLC-ThunkStat.json")
run([
    str(devkit / "bin/LoreHLR"), "stat",
    "-s", str(stat),
    "-o", str(output / "HLR-Stat.json"),
    "-p", str(output),
    *sources,
])
run([
    str(devkit / "bin/LoreHLR"), "batch",
    "-s", str(stat),
    "-o", str(source),
    "-p", str(output),
    *sources,
])
