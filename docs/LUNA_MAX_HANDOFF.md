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

## O6 result: 8 GB residency and texture pressure

Static source tracing is complete; target-runtime pressure and streaming validation remain
pending installation. DXGI `QueryVideoMemoryInfo` reports process-local and non-local
budgets/usage. Texture-copy admission uses the moving local budget, a budget-scaled floor,
headroom reserved for host render targets and shadows, and a 50-97% configurable ceiling
(default 90%). The default per-frame texture staging budget at an 8 GiB budget is 192 MiB,
with a 250 ms pass window; the 32 GiB host default caps it at 128 MiB before backlog
catch-up. Commit admission keeps 512 MiB free for normal texture passes and 1 GiB before
speculative staging-pool growth. Pressure is hysteretic, and reusable staging blocks are
separate from dedicated VRAM accounting.

Do not set `VICTORY_TEXTURE_STAGE_MB` casually: an explicit value bypasses the automatic
shared prefetch clamp (64 MiB in ordinary pressure/limited-RAM conditions and 16 MiB under
critical commit pressure), although the texture-room and commit-admission gates still run.
The supplied profiles leave it unset. Both bounded review responses made unsupported
claims about atomic ordering and staging ownership; source tracing found no use-after-free,
ownership leak, or synchronization defect. `Relaxed` here protects independent telemetry
or atomic state, not a data-publication protocol; the `room_lately` cache is a deliberate
100 ms amortization of DXGI queries. No code patch is justified without measured target
pressure or a reproducible defect.

## O2 result: selected Vice-Tay #37 texture, upload, wait, and shader paths

The selected PR #37 audit is recorded in `docs/fork-comparison.md`. The upload copy queue
is not ported: it retains peak bounce slots without trimming, and its error paths need
device-loss validation before reuse. The texture store is not ported: it does not lower
VRAM use, files are never trimmed, and pending jobs hold full texture copies on an
unbounded channel. The Wave32 `lane_uniform` proof remains a separate shader task; the
donor reports three extra structure-builder programs translated but says the opt-in
builder still crashes in a world run.

The one focused port is `VICTORY_FILL_TITLE=2` in source commit `32a13f7`. Mode `1` stays
unchanged, unset/unknown/`0` still waits, and no supplied profile enables mode `2`. The
predicate tests passed 3/3 with the pinned toolchain. The bounded upload-queue model review
(`chatcmpl-af131c61fafec10b`) incorrectly claimed a shader descriptor transition was
missing and that queue creation recursively locked the mutex; both claims were rejected
after source tracing. No gameplay correctness, stability, frametime, or FPS result exists.

## O7 result: clean Release and diagnostic build

The focused source commit is `32a13f7`; this documentation records the completed O2 audit.
The clean build is `20261127-033517-Both-thinlto-native-5aaf5812`, built at source commit
`960828f7eb1c141be2176e17fe09abd9e7c0650b` with `SourceDirty=false`, Rust/Cargo 1.98.1,
MSVC, DXC 10.0.26100.0, Thin LTO, and native CPU code generation. Both executables return
success for `--help`. SHA-256: Release
`F172EF1C49219FC8A093EB0392ACC96FD98AF77390823E6B9CA2AC4D1C2A392E`; Diagnostic
`1931A334F428B646F107FC067DCA6DC78FA20C3DD0BE30959AD28B01FB0F6A42`. The focused
`fill_title_mode_tests` suite passed 3/3. None of these checks verifies actual rendering,
memory pressure during gameplay, stability, or FPS.

## Next exact task: O8 runtime readiness

The reviewed source and documentation commits are pushed. Local `main` and `origin/main`
both resolve to `86130f718b66ce7a4ad5b576a9e1e26aab6f897a`, and the worktree is clean.
Inspect read-only whether the authorized installation is complete and refresh hardware and
commit-headroom telemetry. The last sample had 9.32 GiB available commit, below the 12 GiB
launcher floor; do not start the runtime unless a fresh sample passes preflight. If ready,
keep shader prewarm separate from gameplay settings, capture Stability/Balanced baseline
first, then A/B `VICTORY_FILL_TITLE=2` with matched routes, cache state, and visual review.
Keep O6 streaming validation queued. Do not enable mode 2 in supplied profiles or make
visual/FPS claims until those runs pass.

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
