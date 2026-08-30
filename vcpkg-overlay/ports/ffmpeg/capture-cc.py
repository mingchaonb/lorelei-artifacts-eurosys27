#!/usr/bin/env python3
"""Run FFmpeg's selected C compiler and record production compile commands."""

import fcntl
import json
import os
import pathlib
import sys


real_compiler = os.environ["FFMPEG_REAL_CC"]
log_path = pathlib.Path(os.environ["FFMPEG_COMPILE_LOG"])
arguments = sys.argv[1:]

if "-c" in arguments and "-o" in arguments:
    source_argument = next(
        (argument for argument in reversed(arguments) if argument.endswith(".c")), None
    )
    if source_argument is not None:
        directory = pathlib.Path.cwd()
        source = pathlib.Path(source_argument)
        if not source.is_absolute():
            source = directory / source
        output = pathlib.Path(arguments[arguments.index("-o") + 1])
        if not output.is_absolute():
            output = directory / output
        entry = {
            "arguments": [real_compiler, *arguments],
            "directory": str(directory),
            "file": str(source.resolve()),
            "output": str(output.resolve()),
        }
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a") as stream:
            fcntl.flock(stream, fcntl.LOCK_EX)
            stream.write(json.dumps(entry, sort_keys=True) + "\n")
            stream.flush()
            fcntl.flock(stream, fcntl.LOCK_UN)

os.execv(real_compiler, [real_compiler, *arguments])
