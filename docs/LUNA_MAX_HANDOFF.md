# Luna Max continuation handoff

Use this file when a new orchestration session resumes the current work. Follow it
literally before proposing a new patch.

## Mandatory first actions

1. Read `AGENTS.md`, `README.md`, `docs/OPERATIONAL_PLAN.md`, the latest sections of
   `docs/progress-journal.md`, `docs/fork-comparison.md`, `docs/source-credits.md`, and
   `third_party/nvidia-3070-VI/LOCAL-CHANGES.md`.
2. Run `git status --short --branch` and `git log -3 --oneline --decorate`. Preserve all
   existing changes. Never reset, clean, overwrite, or amend unknown work.
3. Confirm `origin/main` and local `main` state before committing. The user has already
   authorized focused commits and pushes for completed, reviewed work.
4. Never put the private application title, publisher, executable, game path, save data,
   raw capture, model key, or personal path in tracked files or public reports.

## Exact state at handoff

- Target: desktop RTX 3070 8 GB, Ryzen 7 7700X 8C/16T, 32 GiB RAM, Windows 11.
- Base: COOL_FOX Pareto-residency descendant through the NVIDIA 8 GB source subtree.
- Clean Release and diagnostic builds existed before the current descriptor change.
- The authorized runtime installation was not yet visible in the inspected game-library
  path. Do not launch until it is complete and the launcher preflight passes.
- Latest available commit-memory sample was 9.32 GiB, below the 12 GiB launch floor.
  This is volatile; refresh it immediately before any launch and never bypass the guard.
- Vice-Tay reference checkout is outside Git under
  `%LOCALAPPDATA%\AstraForge\references\Vice-Tay`, audited at `cc9ed86`.
- The current source change canonicalizes resource padding and unused SRV/UAV union
  words before placed-view shape keying. It is a focused port of Vice-Tay #27 commits
  `f07e54a2` and `ce914907`.
- Focused test results already obtained:
  - `placed_views_ignore`: 2 passed, 0 failed.
  - `descriptor::tests`: 10 passed, 0 failed.
- Do not repeat or broaden those tests unless the patch changes further. A full pinned
  Release/diagnostic build is still required before calling this source group built.

## local model orchestration contract

The user wants this session to orchestrate the remote `op-coding` model. Do not use
OpenCode. Local user environment variables provide the endpoint, model ID, and API key.
Never print their values or include them in a command, prompt, log, diff, commit, or
response.

Use `tools/Invoke-AstraForgeModelReview.ps1`. It sends explicit public text files only,
stores responses under `%LOCALAPPDATA%\AstraForge\model-reviews`, and cannot edit the
checkout. Keep `-MaxTokens 4096`; larger values produced API HTTP 422. Keep each request
below the default 450 KiB ceiling and split subsystems into separate reviews.

One completed review has request ID `chatcmpl-b1dadf6286419569`. It correctly found the
uncanonicalized placed-view key but falsely said the `SHAPES` limit was missing. Source
shows `const SHAPES` and `Views::shape` already enforce the 2^22 limit. This is the model
governance rule: accept no finding until exact local symbols and call paths confirm it.

## Next exact task: O4 lock contention

Do not merge Vice-Tay #37. Review only the structured-view `shadow::exact` path:

1. First model request: provide local `descriptor/host.rs` plus the donor
   `docs/findings-rtx4090.md`. Ask it to trace the caller of `shadow::exact`, conditions
   that reach it, frequency implications, and correctness purpose. No patch proposal.
2. Second model request: provide local `shadow.rs` plus the same donor finding. Ask it to
   identify the exact global lock, lock scope, allocation/copy work performed under it,
   and ownership/lifetime invariants. No caller assumptions.
3. Independently inspect `structured_shadow`, `shadow::exact`, shadow registration,
   overlap handling, and every consumer of the returned `Arc<Shadow>`.
4. Compare the local code with Vice-Tay's gate behind `VICTORY_STRUCTURED_RAW`. Do not
   invent or copy the variable until the local source semantics are proven.
5. Classify the donor change as applicable, already present, unsafe, or requiring runtime
   evidence. Prefer a correctness-preserving reduction of lock scope over disabling work.
6. If a patch is justified, add a focused concurrency/lifetime regression test, run the
   relevant GPU tests, update provenance/rollback/docs, then run the pinned build.

## Commit and publication gates

- Before commit: run PowerShell parser checks for changed scripts, focused Rust tests,
  `git diff --check`, inspect the entire diff, and scan tracked changes for credentials,
  personal paths, and prohibited public identifiers.
- Update `OPERATIONAL_PLAN.md` and `progress-journal.md` with exact commands/results and
  evidence limits.
- Keep model responses and generated artifacts outside Git.
- Use a focused commit message. Push only after the staged diff matches the documented
  change. Report commit hash and whether `main` equals `origin/main`.
- Never claim a memory, visual, stability, or FPS improvement from unit tests. Those
  claims require repeatable gameplay captures on the target PC after installation.
