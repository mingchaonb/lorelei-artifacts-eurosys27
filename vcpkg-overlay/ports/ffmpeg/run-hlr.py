#!/usr/bin/env python3
"""Generate and apply one HLR context for each configured FFmpeg DSO."""

import argparse
import json
import pathlib
import shutil
import subprocess


LIBRARIES = {
    "avutil": 59,
    "swresample": 5,
    "swscale": 8,
    "avcodec": 61,
    "avformat": 61,
    "avfilter": 10,
    "avdevice": 61,
}


def run(command: list[str], *, stdout=None) -> None:
    print("+", subprocess.list2cmdline(command), flush=True)
    subprocess.run(command, check=True, stdout=stdout)


def normalize_entry(entry: dict) -> dict:
    directory = pathlib.Path(entry["directory"])
    source_file = pathlib.Path(entry["file"]).resolve()
    normalized = []
    take_path = False
    for argument in entry["arguments"]:
        if take_path:
            path = pathlib.Path(argument)
            normalized.append(str((directory / path).resolve()) if not path.is_absolute() else argument)
            take_path = False
            continue
        if argument in ("-I", "-iquote", "-isystem"):
            normalized.append(argument)
            take_path = True
            continue
        for prefix in ("-I", "-iquote", "-isystem"):
            if argument.startswith(prefix) and len(argument) > len(prefix):
                path = pathlib.Path(argument[len(prefix):])
                if not path.is_absolute():
                    argument = prefix + str((directory / path).resolve())
                break
        if not argument.startswith("-"):
            path = pathlib.Path(argument)
            resolved = path.resolve() if path.is_absolute() else (directory / path).resolve()
            if resolved == source_file:
                argument = str(source_file)
        normalized.append(argument)
    copied = dict(entry)
    copied["arguments"] = normalized
    copied["file"] = str(source_file)
    return copied


parser = argparse.ArgumentParser()
parser.add_argument("--devkit", required=True)
parser.add_argument("--source", required=True)
parser.add_argument("--build", required=True)
parser.add_argument("--port", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--installed-include", required=True)
args = parser.parse_args()

devkit = pathlib.Path(args.devkit).resolve()
source = pathlib.Path(args.source).resolve()
build = pathlib.Path(args.build).resolve()
port = pathlib.Path(args.port).resolve()
output = pathlib.Path(args.output).resolve()
installed_include = pathlib.Path(args.installed_include).resolve()
output.mkdir(parents=True, exist_ok=True)

capture_log = build / "compile-commands.jsonl"
entries = [normalize_entry(json.loads(line)) for line in capture_log.read_text().splitlines()]
entries = list({(entry["file"], entry["output"]): entry for entry in entries}.values())
(build / "compile_commands.json").write_text(json.dumps(entries, indent=2) + "\n")

for name, soname in LIBRARIES.items():
    library = build / f"lib{name}/lib{name}.so.{soname}"
    if not library.exists():
        raise SystemExit(f"HLR input library not found: {library}")

    audit = output / name
    generated = output / "generated" / name
    thunk = audit / "thunk-stat"
    audit.mkdir(parents=True, exist_ok=True)
    generated.mkdir(parents=True, exist_ok=True)

    # Keep the analyzed API surface deterministic. These symbol lists are the
    # public imports of the installed CLI and configured FATE executables, not
    # generated HLR source.
    symbols = port / f"lorelei/{name}/Symbols.conf"
    desc = port / f"lorelei/{name}/Desc.h"
    shutil.copy2(symbols, audit / "Symbols.conf")

    run([
        str(devkit / "bin/LoreMakeThunk.py"),
        "--name", name,
        "--out", str(thunk),
        "--lib", str(library),
        "--symbols", str(symbols),
        "--desc", str(desc),
        "--no-callback-replace",
        "--devkit", str(devkit),
        "--keep-intermediates",
        "--",
        f"-I{source}",
        f"-I{build}",
        f"-I{installed_include}",
        "-D__STDC_CONSTANT_MACROS",
    ])

    target_entries = [
        entry for entry in entries
        if f"/lib{name}/" in entry["output"]
        and pathlib.Path(entry["file"]).suffix == ".c"
        and pathlib.Path(entry["file"]).is_relative_to(source)
    ]
    sources = sorted({entry["file"] for entry in target_entries})
    if not sources:
        raise SystemExit(f"No production C translation units found for lib{name}")
    (audit / "compile_commands.json").write_text(json.dumps(target_entries, indent=2) + "\n")
    (audit / "hlr-sources.txt").write_text("\n".join(sources) + "\n")

    stat = thunk / f".gen/{name}/ThunkStat.json"
    shutil.copy2(stat, audit / "TLC-ThunkStat.json")
    run([
        str(devkit / "bin/LoreHLR"), "stat",
        "-s", str(stat),
        "-o", str(audit / "HLR-Stat.json"),
        "-p", str(audit),
        *sources,
    ])
    run([
        str(devkit / "bin/LoreHLR"), "batch",
        "-s", str(stat),
        "-o", str(generated),
        "-p", str(audit),
        *sources,
    ])
