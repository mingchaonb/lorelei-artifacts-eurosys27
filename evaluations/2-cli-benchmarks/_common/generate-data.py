#!/usr/bin/env python3
"""Generate deterministic, mixed-compressibility benchmark data."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def xorshift64(value: int) -> int:
    value ^= value << 13 & 0xFFFFFFFFFFFFFFFF
    value ^= value >> 7
    value ^= value << 17 & 0xFFFFFFFFFFFFFFFF
    return value & 0xFFFFFFFFFFFFFFFF


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--size-mib", type=int, default=64)
    args = parser.parse_args()

    target_size = args.size_mib * 1024 * 1024
    repeated = (b"Lorelei AE deterministic compression workload\n" * 2048)[:65536]
    state = 0x4C4F52454C454941
    random_block = bytearray()
    while len(random_block) < 65536:
        state = xorshift64(state)
        random_block.extend(state.to_bytes(8, "little"))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("wb") as stream:
        written = 0
        while written < target_size:
            source = repeated if (written // 65536) % 4 != 3 else random_block
            chunk = source[: min(len(source), target_size - written)]
            stream.write(chunk)
            written += len(chunk)

    digest = hashlib.sha256(args.output.read_bytes()).hexdigest()
    print(json.dumps({"path": str(args.output), "bytes": target_size, "sha256": digest}))


if __name__ == "__main__":
    main()
