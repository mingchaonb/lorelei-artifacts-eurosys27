# EuroSys 2027 Lorelei Submission - Artifacts

[中文版](README.zh-CN.md)

This repository is the public artifact and evidence workspace for the EuroSys 2027 Lorelei submission. It contains the material needed to build the artifact, run its evaluations, inspect raw observations, and reproduce reported results.

## Naming

- **Lorelei** is the project name and the name used by the public source and artifact repositories.
- **Hecate** is the anonymized system name used in the double-blind paper submission and during artifact preparation.
- AE scripts, binaries, logs, environment variables, and historical results may continue to use Hecate identifiers.
- Unless a document explicitly distinguishes them, Lorelei and Hecate refer to the same system.

## Repository Contract

### Scope

This repository owns:

- artifact setup and build scripts
- pinned dependency and source revisions
- experiment drivers and test inputs
- machine-readable environment records
- raw command output and measurements
- derived summaries, tables, and plots
- instructions for artifact evaluators

The following material remains outside this repository:

- the manuscript, internal coordination notes, and paper-side interpretation, which remain in the paper repository
- Lorelei, QEMU, thunk libraries, and third-party projects, which remain in their respective source repositories

This repository records the exact source revisions and patches required by each experiment.

### Planned Layout

```text
README.md                 this contract and the evaluator entry point
docs/                     setup, architecture, and experiment guides
scripts/                  repeatable setup, build, test, and analysis commands
configs/                  version pins and experiment configurations
patches/                  reviewed source patches required by the artifact
inputs/                   redistributable fixed test inputs or fetch manifests
results/                  committed evidence, organized by claim group
results/README.md         result taxonomy and shared evidence rules
results/library-tests/    83-target API and correctness evidence
results/workloads/        eight command-line workload results
results/games/            game frame-rate and playability results
results/microbenchmarks/  call, callback, and mechanism overhead results
results/source-analysis/  function, coverage, and modification statistics
```

Do not commit:

- generated build trees
- compiler caches
- installed prefixes
- downloaded source archives
- temporary files

### Evidence Requirements

Every reported result must have a self-contained directory under the applicable claim group in `results/`. A result is not accepted as paper evidence unless that directory records:

- the date and a stable experiment identifier
- machine hardware, operating system, kernel, CPU policy, and relevant device state
- source repository URLs, exact Git revisions, release versions, and local patch hashes
- compilers, build systems, build options, and dependency versions
- the complete command line and all relevant environment variables
- input identity, size, provenance, and checksum
- unedited raw stdout, stderr, exit status, and timing observations
- a machine-readable summary derived from the raw observations
- the analysis command or script used to produce each aggregate value

Performance evidence must satisfy these requirements:

- record at least five repetitions unless an experiment guide specifies a stronger protocol
- report the median and dispersion or range
- document the warm-up policy, timeout policy, and system load checks
- retain failed, interrupted, and excluded runs with their reasons

Correctness evidence is claim-scoped. A support claim must cover the relevant parts of the pass-through boundary:

- selected public APIs
- ABI and data conversion
- callbacks
- variadic calls
- allocator ownership
- representative C control flow used by the evaluation workload

The artifact does not claim that every upstream test category passes. Categories outside a target's support claim may include:

- fuzz and sanitizer tests
- stress and long-duration tests
- concurrency and signal behavior
- private ABI tests
- platform and device integration tests

Before reporting a pass, each supported target must define:

- the tested API surface
- the evaluation workload
- the boundary mechanisms exercised
- the upstream tests included and omitted
- the reason for each material omission

The corresponding evidence should include:

- deterministic algorithm tests
- representative public-API paths
- tests for the relevant boundary mechanisms
- output comparison against a native reference where practical

An upstream suite may be used in full or as a documented subset. A subset is acceptable when omitted tests exercise behavior outside the stated boundary or are unsuitable for reproducible AE execution.

The following items are not sufficient evidence by themselves:

- a smoke test
- a successful build
- a generated thunk count

Handle unsupported and failing tests as follows:

1. Preserve the observed failure and its execution context.
2. Classify the failure by mechanism.
3. Determine whether the failing path is part of the stated support claim.
4. Treat a failure in an advertised pass-through path as a target failure.
5. Record an out-of-scope failure without automatically invalidating the target.

Every claim must name the execution lanes it uses. The current SDL2 work uses the native and Hecate lanes and does not require a pure-QEMU comparison lane.

After review, raw evidence is append-only:

- create a new result directory for a replacement run
- use a clearly identified amendment for a correction
- do not silently rewrite logs or measurements that supported a reported conclusion

### Reproducibility Rules

- Prefer noninteractive scripts that fail on errors and print the commands they execute.
- Pin released source versions where practical. Record a full commit hash even when using a tag.
- Verify downloaded inputs and archives with SHA-256.
- Build tested libraries from source rather than relying on unrecorded system packages.
- Keep architecture-specific build and install trees separate.
- Detect the actual loaded guest, host, GTL, HTL, runtime extension, and dependent shared objects.
- Never update a paper number before its raw evidence and derivation are committed here.
- Define support in terms of the tested configuration, public API surface, boundary mechanisms, and workloads.
- Distinguish pass-through failures from failures caused by unsupported upstream subsystems or test infrastructure.
- Do not claim complete upstream compatibility unless the complete applicable suite was actually run and passed.

### Portability and Safety

Committed scripts must not depend on:

- a contributor's home directory
- a machine name
- credentials or access tokens
- a proxy address
- other private machine state

Put machine-local paths in ignored local configuration or command-line parameters. Never commit:

- secrets or private keys
- access tokens
- core dumps
- proprietary inputs

Safety requirements are:

- restrict destructive cleanup to a validated artifact build or temporary directory
- do not overwrite unrelated source checkouts
- do not overwrite uncommitted work

### Contribution Rules

Contributions must follow these rules:

- use English for canonical public documentation, scripts, metadata keys, and comments, with designated translations such as `README.zh-CN.md` kept in sync
- keep filenames stable after a guide or result references them
- review generated summaries against their raw inputs before committing them
- use short and factual commit messages
- do not add automated authorship trailers

The repository may be incomplete while artifact preparation is in progress. A feature, library, or result becomes available to evaluators only after this repository contains:

- its public instructions
- all required files
- its verification evidence

## Current Work

- Target: SDL2 2.28.5
- Upstream commit: `15ead9a40d09a1eb9972215cceac2bf29c9b77f6`
- Execution lanes: native and Hecate
- Backend scope: SDL dummy backends
- Goal: exercise the HLR path and preserve build, rewrite, and test evidence under this contract
