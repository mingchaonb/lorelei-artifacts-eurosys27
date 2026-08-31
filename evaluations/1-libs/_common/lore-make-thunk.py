#!/usr/bin/env python3
"""Run LoreMakeThunk only when its effective inputs have changed."""

from __future__ import annotations

import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


CACHE_SCHEMA = 1


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def hash_directory(path: Path) -> str:
    digest = hashlib.sha256()
    for entry in sorted(item for item in path.rglob("*") if item.is_file()):
        relative = entry.relative_to(path)
        digest.update(os.fsencode(relative))
        digest.update(b"\0")
        digest.update(hash_file(entry).encode())
        digest.update(b"\0")
    return digest.hexdigest()


def devkit_identity(path: Path) -> object:
    entries = []
    for relative in (
        "bin/LoreTLC",
        "bin/clang++",
        "bin/x86_64-linux-gnu-clang++",
        "lib/libLoreHostRT.so",
        "x86_64/lib/libLoreGuestRT.so",
    ):
        entry = path / relative
        if entry.exists():
            resolved = entry.resolve()
            stat = resolved.stat()
            entries.append((relative, stat.st_size, stat.st_mtime_ns))
    for relative in ("include", "lib/cxx"):
        entry = path / relative
        if entry.is_dir():
            entries.append((relative, hash_directory(entry)))
    return entries


def describe_argument(argument: str, output: Path | None) -> object:
    if output is not None and Path(argument) == output:
        return {"output": True}

    if argument.startswith("-I") and len(argument) > 2:
        include = Path(argument[2:])
        if include.is_dir():
            return {"include": hash_directory(include)}

    if "=" in argument:
        option, value = argument.split("=", 1)
        value_path = Path(value)
        if output is not None and value_path == output:
            return {"option": option, "output": True}
        if value_path.is_file():
            return {"option": option, "file": hash_file(value_path)}
        if option == "-I" and value_path.is_dir():
            return {"option": option, "include": hash_directory(value_path)}

    version_script_marker = "--version-script="
    if version_script_marker in argument:
        prefix, value = argument.split(version_script_marker, 1)
        value_path = Path(value)
        if value_path.is_file():
            return {"argument": prefix + version_script_marker, "file": hash_file(value_path)}

    path = Path(argument)
    if path.is_file():
        return {"file": hash_file(path)}
    return argument


def output_directory(arguments: list[str]) -> Path:
    for index, argument in enumerate(arguments):
        if argument in {"--out", "-o"} and index + 1 < len(arguments):
            return Path(arguments[index + 1])
        if argument.startswith("--out="):
            return Path(argument.split("=", 1)[1])
    raise SystemExit("LoreMakeThunk cache wrapper requires --out or -o")


def outputs_complete(output: Path) -> bool:
    host = list(output.glob("*_HTL.so"))
    guest = list((output / "x86_64").glob("*.so*"))
    return bool(host and guest and all(item.is_file() for item in host + guest))


def fingerprint(tool: Path, arguments: list[str], output: Path) -> str:
    described = []
    devkit_argument = False
    for argument in arguments:
        if devkit_argument:
            described.append({"devkit": devkit_identity(Path(argument))})
            devkit_argument = False
            continue
        described.append(describe_argument(argument, output))
        if argument == "--devkit":
            devkit_argument = True
    description = {
        "schema": CACHE_SCHEMA,
        "tool": hash_file(tool),
        "arguments": described,
    }
    encoded = json.dumps(description, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def restore_cached_output(cached: Path, output: Path, current: str) -> None:
    if output.exists():
        shutil.rmtree(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(cached, output, symlinks=True)
    (output / ".ae-thunk-inputs.sha256").write_text(current + "\n")


def save_cached_output(output: Path, cached: Path, current: str) -> None:
    cached.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=f".{current}.", dir=cached.parent) as temporary:
        staged = Path(temporary) / "artifacts"
        shutil.copytree(output, staged, symlinks=True)
        (staged / ".ae-thunk-inputs.sha256").write_text(current + "\n")
        if cached.exists():
            shutil.rmtree(cached)
        staged.replace(cached)


def main() -> int:
    if len(sys.argv) < 2:
        print(f"Usage: {Path(sys.argv[0]).name} /path/to/LoreMakeThunk.py [arguments...]", file=sys.stderr)
        return 2

    tool = Path(sys.argv[1]).resolve()
    arguments = sys.argv[2:]
    if not tool.is_file():
        print(f"LoreMakeThunk not found: {tool}", file=sys.stderr)
        return 2

    output = output_directory(arguments).resolve()
    stamp = output / ".ae-thunk-inputs.sha256"
    repo_root = Path(__file__).resolve().parents[3]
    cache_root = Path(os.environ.get("LORELEI_TLC_CACHE", repo_root / ".work" / "tlc-cache")).resolve()
    current = fingerprint(tool, arguments, output)
    cached = cache_root / current
    lock_path = cache_root / ".locks" / f"{current}.lock"
    lock_path.parent.mkdir(parents=True, exist_ok=True)

    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if stamp.is_file() and stamp.read_text().strip() == current and outputs_complete(output):
            print(f"Reusing generated TLC artifacts: {output}")
            return 0
        if outputs_complete(cached):
            restore_cached_output(cached, output, current)
            print(f"Restored generated TLC artifacts from cache: {output}")
            return 0

        completed = subprocess.run([str(tool), *arguments], check=False)
        if completed.returncode != 0:
            return completed.returncode
        if not outputs_complete(output):
            print(f"LoreMakeThunk completed without both HTL and GTL outputs: {output}", file=sys.stderr)
            return 1

        stamp.write_text(current + "\n")
        save_cached_output(output, cached, current)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
