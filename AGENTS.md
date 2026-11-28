# Instructions for AI coding agents

These instructions apply to the whole AstraForge repository. Follow any narrower `AGENTS.md` files found below a directory as well. User requests and the repository's GPL-3.0 notices take precedence over guesses made from model memory.

## Mission and current scope

- AstraForge is an open Windows compatibility-layer project. NVIDIA Ampere is the only enabled and locally validated hardware family; AMD and other unimplemented adapters must not be presented as supported.
- The current source is imported under `third_party/nvidia-3070-VI/` as a Git subtree. Root-level tooling and profiles wrap that source.
- The RTX 3070 runtime presets are candidates, not measured rankings. There is no verified local gameplay FPS result or visual validation. Never claim a performance gain, compatibility, or the 30 FPS target without the evidence described in `docs/benchmark-procedure.md`.
- Public project material and benchmark reports must not identify the private application/game, publisher, executable, save, or personal path. Use anonymous scene labels such as `scene-01`.

## Read before editing

For every task, read:

1. `README.md`
2. `docs/project-vision.md`
3. `docs/integration-architecture.md`
4. `docs/progress-journal.md`
5. `docs/source-credits.md`
6. The relevant subsystem docs and, for imported-source edits, `third_party/nvidia-3070-VI/LOCAL-CHANGES.md`

Start with `git status --short --branch` and inspect the current diff. Preserve all pre-existing user changes. Do not reset, clean, overwrite, or amend another contributor's work. Keep changes focused and reversible.

## Engineering rules

- Trace a proposed runtime setting from its parser through every consumer before documenting or using it. Do not invent environment variables, flag meanings, bounds, default values, supported GPUs, or resolution controls.
- Keep hardware identity, GPU-family behavior, and runtime tuning presets separate. A new GPU profile must have its own identity and evidence; do not overwrite or silently retune `nvidia-rtx3070`.
- The imported renderer currently creates its D3D12 device from the first DXGI adapter. Do not claim arbitrary adapter selection until the code implements and tests it.
- Do not copy vendor-specific tuning between architectures without correctness and performance evidence. Do not merge forks wholesale.
- Never remove draws, shader work, synchronization, barriers, or resource lifetime handling to make counters look faster.
- Preserve upstream copyright notices, GPL-3.0 terms, and exact patch provenance. Record each imported change in both `docs/source-credits.md` and the subtree `LOCAL-CHANGES.md` when source is changed.
- Keep game files, caches, saves, raw captures, generated binaries, unredacted hardware inventories, credentials, and API keys outside Git. Never send credentials or private data to a model or service.
- Keep only the newest completed build under the default artifact root. `Build-AstraForge.ps1` removes older managed build folders after the new build and manifest succeed; it leaves build logs, shader caches, prewarm data, and unrelated folders alone.
- Do not call external model APIs or run a game, shader prewarm, or benchmark unless the user has authorized that action. A model suggestion is not evidence.
- Do not create a commit or push unless requested by the user. When requested, use focused commits, inspect the staged diff, and report the resulting commit and remote status.

## Required workflow

1. State the concrete task, affected files, known constraints, and what evidence would count as success.
2. Inspect the relevant implementation and call path before changing it. Use repository-local evidence and primary upstream sources for imported patches.
3. Implement the smallest complete change. Add or update documentation, attribution, profile metadata, and rollback notes when applicable.
4. Run checks that match the risk: parse/format checks for docs and scripts; focused tests for logic changes; the pinned Windows build for Rust/D3D12 changes. Do not imply that unit tests replace a gameplay benchmark or visual review.
5. Review the full diff and scan for secrets, personal paths, unsupported claims, and title-identifying material.
6. Update `docs/progress-journal.md` with what changed, exact commands/results, unresolved limitations, and the next useful action.
7. Report changed paths, checks and their limits, plus any hardware-only follow-up. Separate observed facts from hypotheses.

## Validation commands

Run commands from the repository root unless stated otherwise. The imported Cargo workspace is nested:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Test-AstraForgeBenchmarkHarness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-AstraForge.ps1 -Mode Both
Push-Location .\third_party\nvidia-3070-VI
cargo test --locked --workspace -- --test-threads=1
Pop-Location
```

Choose validation appropriate to the change; do not run a full build for a text-only edit unless the task requires it. The build helper writes generated artifacts and logs outside the repository by default. Real performance or visual claims require real gameplay evidence following `docs/benchmark-procedure.md`.

## Completion note format

Summarize:

- **Changed:** files and behavior/documentation updated.
- **Evidence:** exact checks run and their result.
- **Limits:** what the checks do not establish.
- **Next:** only the remaining action needed to complete the requested task.

For a ready-to-use task prompt and hardware intake, use `docs/AI_CONTRIBUTOR_GUIDE.md` and its linked templates.
