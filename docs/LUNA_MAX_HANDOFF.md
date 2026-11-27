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

## O5 result: NVIDIA shader correctness

Two bounded reviews were completed (`chatcmpl-8dbf8276f41e3d0f` for Wave32/Wave64 and
`chatcmpl-961795fe29590bee` for NaN/BVH). Both responses contained unsupported claims;
manual tracing is authoritative. The host obtains `WaveLaneCountMax` from D3D12 options
and includes the host wave setting and wave-form switches in the shader cache identity.
Wave64 compute shaders on a 32-lane host take exact retries first, with approximate local
wave fallbacks available by default for some forms; `VICTORY_WAVE_LOCAL=idiom` forbids
those approximate forms. `VICTORY_WAVE_WIDE=1` can enable branch widening with barriers;
source comments document a prior device-loss case, so keep it unset unless a specific
shader needs and validates that path. `VICTORY_WAVE_DEEP_SKIPS=0` disables an exact retry.

The local tree has no runtime `VICTORY_NAN_SCRUB` setting. NaN behavior is encoded per
operation in the bitcode optimizer and software BVH tests. The translated ray-node
instruction is software-emulated in shader code; no global ray-disable switch is
implemented. Do not scrub all NaNs or remove ray tests. The model misread the retry and
box/triangle paths; reject both responses' unsupported findings.

Validation: `cargo test --locked -p victory-shader --lib -- --test-threads=1` passed
281 tests with 4 ignored. The targeted
`emit::intersect_tests::the_64_bit_node_test_in_a_host_buffer_matches_the_reference_on_the_card`
passed with `--nocapture`; neither hardware nor WARP reported a missing SM 6.6 device.
These synthetic checks validate shader/reference behavior on the available adapters, not
the complete title's image quality, stability, or FPS.
The full suite initially emitted build artifacts into the imported source's `target`
directory because `CARGO_TARGET_DIR` was unset; those generated files were cleaned.
Point `CARGO_TARGET_DIR` outside the repository for subsequent Cargo work.

## Next exact task: O6 8 GB residency and texture pressure

Trace the current DXGI budget, shared/local memory, staging, texture prefetch, descriptor
retention, and commit-pressure paths before changing policy. Separate dedicated VRAM
budget from system commit and do not assume a larger shared-memory allowance improves
RTX 3070 frame time. Use the existing profile and instrumentation first; wait for runtime
installation before gameplay claims.

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
