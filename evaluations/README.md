# Reproducible evaluations

`evaluations` contains evaluator-facing recipes organized by the claims they support. Each recipe owns its reproducible command, reviewed inputs, raw evidence, and machine-readable summary.

## Evaluation groups

1. `1-libs` validates selected library APIs and boundary mechanisms.
2. `2-cli-benchmarks` measures the eight command-line workloads reported by the paper.
3. `3-breakdown` measures individual call, callback, and mechanism costs.
4. `4-games` measures game performance and playability.

## Evaluation tools

The native FFmpeg utility and the four pinned emulator forks are packaged separately from the libraries under test. Install all of them into the repository-local vcpkg tree from any working directory:

```bash
./evaluations/install-tools.sh
```

The installer reuses packages already present in vcpkg and places the public executables below `vcpkg/installed/arm64-linux/tools/`. The emulator recipes live in `vcpkg-overlay/ports-tools`. Native FFmpeg comes from the built-in vcpkg port, not from the Hecate FFmpeg library-test recipe.

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

Every public recipe reads the Lorelei devkit from `LORELEI_DEVKIT`. The default is the sibling checkout `../lorelei-ae/build/install`, resolved from the artifact repository. Emulator defaults come from `vcpkg/installed/arm64-linux/tools/` after running `evaluations/install-tools.sh`. `QEMU`, `BLINK`, `BOX64`, and `FEX` override those packaged executables. A library recipe may provide `--reference`, `--install-only`, and `--verbose`. Source acquisition, version verification, compilation, and installation belong to the repository-level vcpkg overlay. A recipe must use the repository-local `vcpkg/vcpkg` executable.

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
./evaluations/1-libs/sdl2/run.sh
```

Another devkit or emulator can be selected explicitly:

```bash
LORELEI_DEVKIT=/path/to/devkit QEMU=/path/to/qemu-x86_64 \
  ./evaluations/1-libs/sdl2/run.sh
```

Generated build trees belong below `.work/evaluations/` and are not evidence. Each recipe keeps raw evidence beside the recipe and never overwrites an earlier run.
