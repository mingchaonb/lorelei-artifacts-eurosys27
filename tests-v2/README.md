# Reproducible library tests, version 2

`tests-v2` contains evaluator-facing recipes for claim-scoped library validation. It replaces the historical result-only collection with a uniform build, execution, and evidence contract.

## Directory contract

```text
tests-v2/
├── common/                         shared, versioned recipe inputs
└── libraries/<package>/
    ├── README.md                   scope and evaluator instructions
    ├── run.sh                      single public entry point
    ├── standalone-tests.tsv        selected upstream programs and arguments
    ├── tests/                      directed boundary tests
    ├── tools/                      package-local analysis helpers
    └── results/<run-id>/           append-only evidence for this package

vcpkg-overlay/
├── ports/<package>/                pinned source and package build policy
└── triplets/                       shared native and guest targets

tests-v2/libraries/<package>/results/<run-id>/
├── meta.json                       machine, source, tool, and invocation identity
├── summary.json                    machine-readable classification
├── environment.txt                unedited environment probes
├── commands.log                   complete driver output and command trace
├── generated/                     generated symbol and HLR audit records
└── logs/{build,native,tlc,hlr}/    unedited raw logs and exit statuses
```

Every package recipe must accept the devkit path as its only positional argument. A recipe may accept an emulator path through the `QEMU` environment variable for development, but the release devkit is expected to provide `bin/qemu-x86_64`. Source acquisition, version verification, compilation, and installation belong to the repository-level vcpkg overlay. A recipe must use the repository-local `vcpkg/vcpkg` executable.

Each recipe must perform these stages when applicable:

1. Validate tools and the devkit layout.
2. Ask vcpkg to build the pinned native and guest packages through the shared overlay.
3. Build a pure TLC host package and a distinct HLR host package.
4. Generate the pure TLC thunk with callback replacement enabled.
5. Run HLR from the final host compilation database and apply reviewed adaptations in the HLR port.
6. Generate the HLR thunk with TLC callback replacement disabled.
7. Run the documented native, TLC, and HLR test paths.
8. Classify each transformed lane against the native reference and write append-only evidence.

The public command for a package must fit on one line. SDL2 is the reference implementation:

```bash
./tests-v2/libraries/sdl2/run.sh /path/to/lorelei-devkit
```

During development, a patched QEMU outside the devkit can be selected explicitly:

```bash
QEMU=/path/to/qemu-x86_64 ./tests-v2/libraries/sdl2/run.sh /path/to/lorelei-devkit
```

Generated build trees belong below `.work/tests-v2/` and are not evidence. Each package keeps raw evidence below its own `results/` directory and never overwrites an earlier run.
