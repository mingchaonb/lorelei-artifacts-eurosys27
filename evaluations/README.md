# Reproducible evaluations

`evaluations` contains evaluator-facing recipes organized by the claims they support. Each recipe owns its reproducible command, reviewed inputs, raw evidence, and machine-readable summary.

## Evaluation groups

1. `1-libs` validates selected library APIs and boundary mechanisms.
2. `2-cli-benchmarks` measures the eight command-line workloads reported by the paper.
3. `3-breakdown` measures individual call, callback, and mechanism costs.
4. `4-games` measures game performance and playability.

## Directory contract

```text
evaluations/
├── common/                         shared, versioned recipe inputs
├── 1-libs/<package>/
    ├── README.md                   scope and evaluator instructions
    ├── run.sh                      single public entry point
    ├── standalone-tests.tsv        selected upstream programs and arguments
    ├── tests/                      directed boundary tests
    ├── tools/                      package-local analysis helpers
    ├── reference-results/<run-id>/ author-generated reference evidence
    └── results/<run-id>/           evaluator-generated evidence
├── 2-cli-benchmarks/
├── 3-breakdown/
└── 4-games/

vcpkg-overlay/
├── ports/<package>/                pinned source and package build policy
└── triplets/                       shared native and guest targets
```

Every package recipe must accept the devkit path as its only positional argument and `--reference` as an optional evidence-destination flag. A library recipe may provide `--install-only` to prepare its complete mechanism path without compiling or running tests. A recipe may accept an emulator path through the `QEMU` environment variable for development, but the release devkit is expected to provide `bin/qemu-x86_64`. Source acquisition, version verification, compilation, and installation belong to the repository-level vcpkg overlay. A recipe must use the repository-local `vcpkg/vcpkg` executable.

Each recipe must perform these stages when applicable:

1. Validate tools and the devkit layout.
2. Ask vcpkg to build the pinned native and guest packages through the shared overlay.
3. Build the selected host mechanism package. SDL selects Hecate, which combines TLC thunk generation with HLR rewriting.
4. Run HLR from the final host compilation database and apply reviewed adaptations in the HLR port.
5. Generate the Hecate thunk with TLC callback replacement disabled.
6. Run the documented native and Hecate paths.
7. Classify Hecate against the native reference and write append-only evidence.

The public command for a package must fit on one line. SDL2 is the reference implementation:

```bash
./evaluations/1-libs/sdl2/run.sh /path/to/lorelei-devkit
```

During development, a patched QEMU outside the devkit can be selected explicitly:

```bash
QEMU=/path/to/qemu-x86_64 ./evaluations/1-libs/sdl2/run.sh /path/to/lorelei-devkit
```

Generated build trees belong below `.work/evaluations/` and are not evidence. Each recipe keeps raw evidence beside the recipe and never overwrites an earlier run.
