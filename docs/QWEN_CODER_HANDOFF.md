# Qwen Coder continuation handoff

Updated 2026-11-28. This is the current resume point for Qwen Coder Next 30B or another coding agent. Repository rules in `AGENTS.md` take precedence over this handoff.

## Read first

Read, in order:

1. `AGENTS.md`
2. `README.md`
3. `docs/project-vision.md`
4. `docs/integration-architecture.md`
5. the latest entries in `docs/progress-journal.md`
6. `docs/OPERATIONAL_PLAN.md`
7. `docs/source-credits.md`
8. `third_party/nvidia-3070-VI/LOCAL-CHANGES.md`

Then run `git status --short --branch` and inspect the full diff. Preserve every existing change. Do not reset, clean, amend, or overwrite another contributor's work.

## Current source checkpoint

The active focused change fixes texture refresh across aliased title-memory views:

- texture write/remap notices are retained independently for every subscribed view heap;
- a write through one virtual address is projected to the exact bytes in sibling views of the same 64 KiB physical pages;
- compatibility-layer copies publish the notice after the bytes have landed;
- the physical-page path that already enumerates every view bypasses a second alias projection.

The per-heap prerequisite comes from merged Vice-Tay PR #371 (`059fa1d`, merged as `bc44a9f`). The alias and post-copy portion is a focused adaptation of draft PR #379 (head `ecc003e`, commits `03ecd2f` and `fbfdd3e`). Do not merge either fork wholesale.

Files in this focused change:

- `third_party/nvidia-3070-VI/crates/victory-gpu/src/descriptor/host.rs`
- `third_party/nvidia-3070-VI/crates/victory-gpu/src/host.rs`
- `third_party/nvidia-3070-VI/crates/victory-gpu/src/inplace.rs`
- `third_party/nvidia-3070-VI/crates/victory-gpu/src/lib.rs`
- `third_party/nvidia-3070-VI/crates/victory-gpu/src/watch.rs`
- `third_party/nvidia-3070-VI/crates/victory-hle/src/modules/xmem.rs`
- the source-credit ledger, subtree ledger, and progress journal

## Evidence already collected

- `cargo test --locked -p victory-gpu --lib aliased_texture_writes_reach_each_view_heap -- --test-threads=1 --nocapture`: 1 passed.
- `cargo test --locked -p victory-gpu --lib writes_name_the_exact_bytes_in_sibling_views -- --test-threads=1 --nocapture`: 1 passed.
- `cargo test --locked -p victory-gpu --lib descriptor::host::tests -- --test-threads=1`: 46 passed.
- `cargo check --locked -p victory-gpu -p victory-hle`: passed; 12 existing `victory-gpu` warnings.
- `git diff --check`: passed before the handoff documentation update and must be rerun.

These checks establish focused logic and cross-crate compilation only. They do not establish faster loading, lower RAM/VRAM, higher FPS, visual correctness, or removal of black textures.

## Immediate task

1. Review the complete focused diff and rerun `git diff --check` plus the privacy/unsupported-claim scan.
2. Run the pinned Windows build from the repository root:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Build-AstraForge.ps1 -Mode Both
   ```

   If MSVC tools are absent from `PATH`, enter the installed Visual Studio Build Tools developer environment first. Do not change the build script merely to work around the shell environment.
3. Confirm the build manifest and report warnings. Do not publish a binary while its privacy scan contains a personal compile-time path.
4. The build helper must remove older managed artifact directories only after the new build and manifest succeed. Do not manually accumulate old builds; do not delete outside the helper's managed artifact root.
5. If the build passes, record it in `docs/progress-journal.md`. The user has requested a focused commit and push; inspect the staged diff before doing both and report the commit plus remote status.

## Next engineering investigation

After the current change is safely built and published, inspect the local reference material supplied by the maintainer for memory-coherency, tiled-resource, copy-queue, residency, and texture-upload contracts. Keep that material outside Git and do not name or cite the private documentation in public project files. Explain any resulting implementation in original project language and retain exact public-source provenance for copied source changes.

Start with source tracing, not a large port. The useful questions are:

- Can texture upload preparation be parallelized without changing descriptor publication order or resource lifetime?
- Can temporary detile/upload buffers be bounded or reused without increasing VRAM residency pressure?
- Which GPU-to-CPU copies are required by an observed cache writeback or CPU read, and which are only hypotheses?
- Can 64 KiB mapping information reduce duplicate host/card copies while preserving alias correctness?

Do not remove synchronization, barriers, dirty tracking, draws, or lifetime handling to improve counters. Any lazy copy-back, async submission, tiled-resource, or GPU detile work must be separately gated, reversible, tested, and measured.

## Runtime and publication rules

- Do not run the private application, a benchmark, or shader prewarm without renewed user authorization for that run.
- Use only anonymous scene labels in public material. Never include private application names, executable names, saves, personal paths, raw captures, or hardware inventories.
- Official FPS claims require the repeated matched capture process in `docs/benchmark-procedure.md`. User observations such as an apparent 30 FPS interval remain valuable visual notes, not official benchmark results.
- NVIDIA Ampere is the only enabled and locally validated hardware family. Do not advertise arbitrary NVIDIA GPUs, DLSS, frame generation, AMD, or adapter selection unless the checked source implements and validates them.

## Completion format

Report `Changed`, `Evidence`, `Limits`, and `Next`, exactly as required by `AGENTS.md`.
