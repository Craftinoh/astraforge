# Contributing to AstraForge

Thanks for helping make GPU compatibility work reproducible and easy to integrate. Contributions can add a hardware profile, investigate an engine issue, improve validation, or correct documentation. Start with [`AGENTS.md`](AGENTS.md) for the project-wide rules and [`docs/AI_CONTRIBUTOR_GUIDE.md`](docs/AI_CONTRIBUTOR_GUIDE.md) if you use a coding model.

## Before opening a change

- Keep one change focused and reversible.
- Record the source repository, commit/PR, author, and license for imported code.
- Separate supported facts from guesses. An unmeasured preset must be labeled unmeasured.
- Keep personal game files, raw telemetry, cache contents, local paths, credentials, and unredacted machine reports out of the pull request.
- Do not publish the private application/game or publisher identity. Use neutral scene labels in benchmark material.

## Hardware profile contributions

Start with [`docs/GPU_PROFILE_SUBMISSION.md`](docs/GPU_PROFILE_SUBMISSION.md) and copy [`docs/templates/hardware-report.template.md`](docs/templates/hardware-report.template.md). Capture the machine facts locally, review the report for identifiers, then share only the sanitized fields needed for the issue or pull request.

For the clone, model setup, role split, and maintainer handoff, follow [`docs/CONTRIBUTOR_HANDOFF.md`](docs/CONTRIBUTOR_HANDOFF.md).

A hardware report alone does not enable a GPU. A profile can be marked supported only after adapter selection, required feature checks, telemetry, build/test coverage, and runtime correctness have been verified for that target. The current active profile remains NVIDIA RTX 3070 Ampere.

## Validation

Use the commands and acceptance criteria in the relevant subsystem guide. For Rust/D3D12 source changes, use the repository-pinned toolchain and report the exact command. For runtime performance changes, use matched repeated gameplay captures as defined in [`docs/benchmark-procedure.md`](docs/benchmark-procedure.md); synthetic harness output is not a performance result.

## Pull requests

Fill out the repository pull request template. Include source attribution, tests, limitations, rollback instructions, and benchmark evidence when applicable. Do not attach binaries or raw machine captures.
