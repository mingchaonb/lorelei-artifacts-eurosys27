#!/usr/bin/env python3
"""Audit TLC coverage against the complete exported function set."""

from __future__ import annotations

import csv
import datetime
import json
import os
import pathlib
import shutil
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[3]
DEVKIT = pathlib.Path(os.environ.get("LORELEI_DEVKIT", ROOT / ".work/devkit")).resolve()
WORK = ROOT / ".work/evaluations/coverage-effort"
RESULTS = pathlib.Path(__file__).resolve().parent / "results"


def first_file(root: pathlib.Path, pattern: str) -> pathlib.Path:
    files = sorted(path for path in root.glob(pattern) if path.is_file())
    if not files:
        raise RuntimeError(f"No file matching {pattern} below {root}")
    return files[0]


def exported_functions(path: pathlib.Path) -> list[str]:
    output = subprocess.check_output(
        ["llvm-nm-20", "-D", "--defined-only", "--format=posix", str(path)], text=True
    )
    names = set()
    for line in output.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[1].upper() in {"T", "W"}:
            name = fields[0].split("@", 1)[0]
            if name != "LoreGetFileContext":
                names.add(name)
    return sorted(names)


def write_symbols(path: pathlib.Path, functions: list[str]) -> None:
    path.write_text("[Function]\n" + "\n".join(functions) + "\n")


def write_desc(path: pathlib.Path, headers: list[pathlib.Path]) -> None:
    lines = ["#pragma once", "", 'extern "C" {']
    lines.extend(f'#include "{header.resolve()}"' for header in headers)
    lines.extend(["}", ""])
    path.write_text("\n".join(lines))


def run_tlc(
    name: str,
    dso: pathlib.Path,
    headers: list[pathlib.Path],
    include_dirs: list[pathlib.Path],
    run_dir: pathlib.Path,
) -> dict:
    library_dir = run_dir / "libraries" / name
    library_dir.mkdir(parents=True)
    functions = exported_functions(dso)
    symbols = library_dir / "Symbols.conf"
    desc = library_dir / "Desc.h"
    thunk = WORK / "thunks" / name
    write_symbols(symbols, functions)
    write_desc(desc, headers)
    command = [
        str(DEVKIT / "bin/LoreMakeThunk.py"),
        "--name",
        name,
        "--out",
        str(thunk),
        "--lib",
        str(dso),
        "--symbols",
        str(symbols),
        "--desc",
        str(desc),
        "--no-callback-replace",
        "--devkit",
        str(DEVKIT),
        "--keep-intermediates",
        "--",
        *(f"-I{path}" for path in include_dirs),
    ]
    (library_dir / "command.json").write_text(json.dumps(command, indent=2) + "\n")
    with (library_dir / "tlc.log").open("w") as log:
        completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, text=True)
    stat = thunk / ".gen" / name / "ThunkStat.json"
    if not stat.is_file():
        raise RuntimeError(f"TLC did not produce statistics for {name}, see {library_dir / 'tlc.log'}")
    shutil.copy2(stat, library_dir / "ThunkStat.json")
    data = json.loads(stat.read_text())
    supported = {entry["name"] for entry in data["functions"]["GuestToHost"]}
    missing = set(data["missingFunctions"]["GuestToHost"])
    exported = set(functions)
    return {
        "library": name,
        "dso": str(dso.resolve()),
        "exported_functions": len(exported),
        "hecate_supported_functions": len(exported & supported),
        "hecate_missing_functions": len(exported & missing),
        "hecate_coverage": len(exported & supported) / len(exported),
        "tlc_exit_status": completed.returncode,
        "evidence_dir": str(library_dir.relative_to(ROOT)),
    }


def copy_installed_stat(
    name: str, dso: pathlib.Path, stat: pathlib.Path, run_dir: pathlib.Path
) -> dict:
    library_dir = run_dir / "libraries" / name
    library_dir.mkdir(parents=True)
    functions = set(exported_functions(dso))
    data = json.loads(stat.read_text())
    supported = {entry["name"] for entry in data["functions"]["GuestToHost"]}
    missing = set(data["missingFunctions"]["GuestToHost"])
    shutil.copy2(stat, library_dir / "ThunkStat.json")
    return {
        "library": name,
        "dso": str(dso.resolve()),
        "exported_functions": len(functions),
        "hecate_supported_functions": len(functions & supported),
        "hecate_missing_functions": len(functions & missing),
        "hecate_coverage": len(functions & supported) / len(functions),
        "tlc_exit_status": 0,
        "evidence_dir": str(library_dir.relative_to(ROOT)),
    }


def main() -> None:
    if not (DEVKIT / "bin/LoreMakeThunk.py").is_file():
        raise SystemExit(f"Lorelei devkit not found: {DEVKIT}")
    if shutil.which("llvm-nm-20") is None:
        raise SystemExit("llvm-nm-20 is required")
    run_id = datetime.datetime.now(datetime.UTC).strftime("%Y%m%dT%H%M%SZ")
    run_dir = RESULTS / run_id
    run_dir.mkdir(parents=True)
    shutil.rmtree(WORK / "thunks", ignore_errors=True)

    zlib_prefix = ROOT / ".work/evaluations/zlib/installed/native/arm64-linux-ae"
    zstd_prefix = ROOT / ".work/evaluations/zstd/installed/native/arm64-linux-ae"
    zstd_source = ROOT / ".work/evaluations/zstd/installed/hecate/arm64-linux-ae/tools/zstd/upstream-tests/lib"
    ffmpeg_prefix = ROOT / ".work/evaluations/ffmpeg/installed/native/arm64-linux-ae"
    ffmpeg_tests = ffmpeg_prefix / "tools/ffmpeg/upstream-tests"
    sdl_prefix = ROOT / ".work/evaluations/sdl2/installed/hecate/arm64-linux-ae"
    vulkan_prefix = ROOT / ".work/evaluations/vulkan-loader/installed/arm64-linux-ae"
    gl_prefix = ROOT / ".work/evaluations/glvnd/installed/arm64-linux-ae"

    rows = []
    rows.append(
        run_tlc(
            "zlib",
            first_file(zlib_prefix / "lib", "libz.so.*"),
            [zlib_prefix / "include/zlib.h"],
            [zlib_prefix / "include"],
            run_dir,
        )
    )
    zstd_headers = sorted(zstd_source.rglob("*.h"))
    rows.append(
        run_tlc(
            "zstd",
            first_file(zstd_prefix / "lib", "libzstd.so.*"),
            zstd_headers,
            [zstd_prefix / "include", zstd_source],
            run_dir,
        )
    )
    for library in ("avformat", "avcodec", "avutil"):
        headers = sorted((ffmpeg_prefix / "include" / f"lib{library}").glob("*.h"))
        if library == "avcodec":
            unavailable_platform_headers = {
                "d3d11va.h",
                "dxva2.h",
                "jni.h",
                "mediacodec.h",
                "qsv.h",
                "vdpau.h",
                "videotoolbox.h",
            }
            headers = [header for header in headers if header.name not in unavailable_platform_headers]
        elif library == "avutil":
            headers = [
                header
                for header in headers
                if not header.name.startswith("hwcontext_")
            ]
        rows.append(
            run_tlc(
                library,
                first_file(ffmpeg_prefix / "lib", f"lib{library}.so.*"),
                headers,
                [ffmpeg_prefix / "include", ffmpeg_tests / "source", ffmpeg_tests / "build"],
                run_dir,
            )
        )
    rows.append(
        run_tlc(
            "SDL2",
            first_file(sdl_prefix / "lib", "libSDL2-2.0.so.*"),
            [sdl_prefix / "include/SDL2/SDL.h", sdl_prefix / "include/SDL2/SDL_syswm.h", sdl_prefix / "include/SDL2/SDL_vulkan.h"],
            [sdl_prefix / "include", ROOT / "evaluations/common/include"],
            run_dir,
        )
    )
    vulkan_dso = first_file(pathlib.Path("/usr/lib"), "*-linux-gnu/libvulkan.so.1")
    rows.append(
        copy_installed_stat(
            "Vulkan",
            vulkan_dso,
            vulkan_prefix / "share/vulkan-loader/thunk/.gen/vulkan/ThunkStat.json",
            run_dir,
        )
    )
    gl_dso = first_file(pathlib.Path("/usr/lib"), "*-linux-gnu/libGL.so.1")
    rows.append(
        copy_installed_stat(
            "OpenGL",
            gl_dso,
            gl_prefix / "share/glvnd/thunk/.gen/GL/ThunkStat.json",
            run_dir,
        )
    )

    fields = list(rows[0])
    with (run_dir / "summary.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    (run_dir / "summary.json").write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n")
    print(f"Coverage audit evidence: {run_dir}")
    for row in rows:
        print(
            f"{row['library']}: {row['hecate_supported_functions']}/"
            f"{row['exported_functions']} ({row['hecate_coverage']:.1%})"
        )


if __name__ == "__main__":
    main()
