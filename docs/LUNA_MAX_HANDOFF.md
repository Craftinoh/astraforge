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

## Remote model-review contract

The user wants this session to orchestrate a configured remote coding model through the
repository's bounded review tool. Local user environment variables provide the endpoint,
model ID, and API key. Never print their values or include them in a prompt, log, diff,
commit, or response.

Use `tools/Invoke-AstraForgeModelReview.ps1`. It sends explicit public text files only,
stores responses under `%LOCALAPPDATA%\AstraForge\model-reviews`, and cannot edit the
checkout. Keep `-MaxTokens 4096`; larger values produced API HTTP 422. Keep each request
below the default 450 KiB ceiling and split subsystems into separate reviews. The key
environment variable defaults to `ASTRAFORGE_MODEL_API_KEY`.

One completed review has request ID `chatcmpl-b1dadf6286419569`. It correctly found the
uncanonicalized placed-view key but falsely said the `SHAPES` limit was missing. Source
shows `const SHAPES` and `Views::shape` already enforce the 2^22 limit. This is the model
governance rule: accept no finding until exact local symbols and call paths confirm it.

## O4 result: shadow/resource lock audit

Two separate bounded read-only reviews were completed (`chatcmpl-9685cbb031a1f6d9` for
the descriptor caller and `chatcmpl-920314fe942fcf73` for the shadow implementation).
Both outputs are untrusted and remain outside Git. Independent source tracing confirmed
that `view_home` can call `shadow::exact` for misaligned raw, structured, and typed buffer
views when `VICTORY_VIEW_BYTES` is enabled; the local tree has no
`VICTORY_STRUCTURED_RAW` setting. The donor's switch therefore cannot be copied as-is,
and the existing `VICTORY_VIEW_BYTES=0` path leaves affected views null rather than
preserving the exact copy's correctness behavior.

`EXACT` is a process-wide mutex around an address/length cache. On misses its critical
section includes stale-entry checks, shared D3D12 resource creation/residency/mapping,
`Shadow` and page-bitmap construction, and map insertion. `exact` itself does not copy
view bytes: list refreshes later retain an `Arc<Shadow>` until list reset and bring the
requested range up to date. Cache eviction also consults `Arc` and COM reference counts.
No source patch is selected without target-side contention and call-volume evidence; a
lock-scope change must prevent duplicate allocations and preserve map/descriptor/list
lifetime guarantees.

## Next exact task: O5 NVIDIA shader correctness

Audit the existing Wave32 translation, NaN scrubbing, incompatible ray-path handling,
and known black/flat rendering symptoms in independent bounded groups. Trace each setting
and code path in the local source; do not port shader changes from another architecture
without correctness evidence. Add a patch only when a concrete local defect and focused
validation route are established.

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
