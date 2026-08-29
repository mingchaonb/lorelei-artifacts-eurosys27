# SDL2 run evidence

Each successful or failed invocation creates a timestamped directory here. A run directory contains the exact environment and command identity, raw build logs, native logs, TLC logs, HLR logs, generated audit inputs, and `summary.json`.

Run directories are append-only. Rerunning the recipe creates a new timestamp rather than modifying prior evidence.
