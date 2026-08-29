# Result Groups

Results are grouped by the paper claim they support. A directory appearing under `results/` does not imply that every contained experiment supports the same claim.

## Groups

### `library-tests/`

This group contains the API, algorithm, and pass-through correctness evidence used for the 83 shared-library ABI targets. Its package-level schema is defined in [`library-tests/SCHEMA.md`](library-tests/SCHEMA.md).

A `pass` in this group means that the target passed its documented claim-scoped test surface. It does not imply that every upstream regression, fuzz, stress, private-ABI, or platform-integration test passed.

### `workloads/`

This group contains the eight command-line workloads used for end-to-end performance evaluation. Each workload should record:

- the program and library versions
- the fixed input dataset
- build and runtime configuration
- execution lanes and baselines
- at least five raw timing repetitions
- the derived median and dispersion or range
- correctness checks for generated output

### `games/`

This group contains frame-rate and playability evidence for game workloads. Each game should record:

- the exact game build and assets
- display, rendering, and resolution settings
- graphics driver and device state
- frame collection and warm-up intervals
- raw frame-time or FPS observations
- aggregation and plotting commands
- known sources of run-to-run variation

### `microbenchmarks/`

This group contains focused measurements of individual mechanisms, including call overhead, callback detection, callback reentry, and relevant comparison systems. Each experiment must state which mechanism it isolates and which effects remain in the measurement.

### `source-analysis/`

This group contains static and source-derived results, including function counts, thunk coverage, manual adaptation effort, and code modification statistics. Each result must record:

- the analyzed revisions
- inclusion and exclusion rules
- the exact analysis command or script
- raw tool output
- the derivation of the reported number

## Shared Rules

- Store raw observations below the claim group that consumes them.
- Do not copy one raw log into multiple groups. Link to its canonical relative path when another claim reuses it.
- Keep correctness evidence separate from performance evidence even when both use the same program.
- Give every experiment a stable identifier that does not depend only on its date.
- Record superseded runs instead of overwriting them.
- Keep group-specific schemas next to the group when their metadata or directory layouts differ.
