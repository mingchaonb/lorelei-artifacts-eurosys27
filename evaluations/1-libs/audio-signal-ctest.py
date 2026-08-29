#!/usr/bin/env python3
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys


build = pathlib.Path(sys.argv[1]).resolve()
source = pathlib.Path(sys.argv[2]).resolve()
mode = sys.argv[3]
excluded = set(sys.argv[4:])


def remap(value):
    value = re.sub(
        r"/[^\s;]+/buildtrees/[^/]+/(?:arm64|x64)-linux-ae-rel",
        str(build),
        str(value),
    )
    value = re.sub(
        r"/[^\s;]+/buildtrees/[^/]+/src/[^/]+\.clean",
        str(source),
        value,
    )
    return value
suite = json.loads(
    subprocess.check_output(
        ["ctest", "--test-dir", str(build), "--show-only=json-v1"], text=True
    )
)
passed = 0
skipped = 0
for test in suite["tests"]:
    name = test["name"]
    if name in excluded or "command" not in test:
        print(f"SKIP {name}", flush=True)
        skipped += 1
        continue
    command = [remap(argument) for argument in test["command"]]
    workdir = build
    for prop in test.get("properties", []):
        if prop["name"] == "WORKING_DIRECTORY":
            workdir = pathlib.Path(remap(prop["value"]))
    executable = pathlib.Path(command[0])
    if mode == "hecate" and executable.is_file() and executable.read_bytes()[:4] == b"\x7fELF":
        command = [*shlex.split(os.environ["HECATE_TEST_RUNNER"]), *command]
    print(f"RUN {name}", flush=True)
    completed = subprocess.run(command, cwd=workdir, env=os.environ.copy())
    if completed.returncode:
        print(f"FAIL {name} exit={completed.returncode}", flush=True)
        sys.exit(completed.returncode)
    passed += 1
    print(f"PASS {name}", flush=True)
print(f"SUMMARY pass={passed} skip={skipped}", flush=True)
