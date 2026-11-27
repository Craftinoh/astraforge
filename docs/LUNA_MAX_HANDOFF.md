# Luna Max continuation handoff

Use this file when a new orchestration session resumes the current work. Follow it
literally before proposing a new patch.

## Latest checkpoint - 2026-11-27, O4 diagnostic contention telemetry

- The O4 diagnostic telemetry source commit `f0c57bb`, its build-verification docs, and the latest runtime-readiness notes are published on `origin/main`; the push succeeded and the worktree was clean. The focused work branch `fix/per-heap-bake-coverage` remains available. Check `git status` and fetch remote refs before continuing.
- Adapted merged Vice-Tay PR #85 (`7eef143`) to the local `TextureQueue`: bake completion now belongs to a heap/revision, overlapping scans cannot certify, and capped due/lookahead snapshots must be complete. Synchronous GPU coverage is recorded after execution and descriptor publication.
- Added queue-locality, stale-revision, overlap, and truncated-snapshot regressions. Serial diagnostic tests pass 407/0/35 ignored; optimized Release tests pass 349/0/34 ignored. Clippy exits 0 with existing warnings outside these edits.
- Parallel runs were flaky: one diagnostics process exited `0xc0000005`; another run's texture-ahead test panicked. Keep that caveat in the journal. The whole-file rustfmt check reports extensive pre-existing formatting differences in these imported files, so do not format them wholesale.
- Commit `f0c57bb6f6c9a0083ba7781592bd3747b8ee1c0a` has a clean pinned application Release/diagnostic build: `20261127-053816-Both-thinlto-native-ee1e228c`, `SourceDirty=false`; Rust/Cargo 1.98.1, MSVC 14.44.35207, DXC 10.0.26100.0, Thin LTO, one release codegen unit, native CPU. Both executables return exit code 0 for `--help`. SHA-256: Release `9E04D58DCD83C66B82B541E6CAF5EC188C5A8905E7ED730426A6283A0E8EAAB6`; diagnostic `8DC38F48F84EC2E1924F53FCE155585589A59BC81E77540342C84BBD5AF7104D`. Artifacts remain outside Git. Do not claim gameplay/FPS/visual results.
- O4 now has diagnostic-only telemetry for blocked exact-view cache mutex acquisitions: count, mean, maximum, and six wait buckets. The Release lock path is unchanged. The boundary test and full serial diagnostic GPU suite pass (408 passed, 35 ignored); Clippy exits 0 with no warning in the modified lines. Use these metrics only to decide whether a lock-scope change is justified, not as Release performance evidence.
- Rechecked the resolution path directly: `dxgi::display_size` reports `VICTORY_DISPLAY_MODE` as the guest mode list, while `Host::present_planes` creates/resizes the swapchain from the actual presented texture dimensions. This source has no independent 720p internal render-scale or 1080p upscaler control; the four presets cannot claim that path.
- The latest local hardware probe at 11:54 CET reports 10.31 GiB available commit and 11.61 GiB available physical RAM, below the 12 GiB launch floor by 1.69 GiB. The full report stays outside Git. The user confirmed the single executable candidate in the external install directory. `VICTORY_GAME_DIR` and `VICTORY_GAME_EXE` remain unset, but the launcher accepts explicit paths. Do not launch until the commit gate passes. All 15 commit-preflight cases and six benchmark-harness checks pass.
- The user explicitly requires the game installation to remain untouched. Inspections are read-only; the launcher and benchmark keep logs, cache, and runtime data outside the game directory and repository. Never modify, rename, move, overwrite, or delete installed files; stop if an output path resolves inside the install.

## Latest checkpoint - 2026-11-27 03:29 UTC

- The local Vice-Tay reference clone is still at `cc9ed86`; Git fetch failed earlier
  because DNS was unavailable. A read-only GitHub API audit now sees default-branch
  commit `123c4b7`, following merge `0ef44bc` (#116). The combined PR includes #114;
  it reports combined checks, but its frame-time comparison is not isolated by patch.
- Ported the focused `Shadow::differing` first-piece alignment correction from Vice-Tay
  #114, adapted from fxceless #1407 and credited to the original Kelvaroq finding. The
  added 48 MiB test failed against the old expression with a debug overflow, then passed
  1/1 in debug and 1/1 in optimized Release after the saturating-subtraction fix.
- The entire `victory-gpu` library suite passes: 346 passed, 0 failed, 34 ignored. The
  focused regression passes in debug and optimized Release. Existing compiler warnings
  remain.
- Commit `abcb2750a4c17349c44c1026394041682ed337f0` has a clean pinned Release/diagnostic
  build: `20261127-042402-Both-thinlto-native-7e316a03`, `SourceDirty=false`, Rust/Cargo
  1.98.1, MSVC target `x86_64-pc-windows-msvc`, DXC 10.0.26100.0, Thin LTO and native
  CPU. Both executables return success for `--help`. SHA-256: Release
  `E20A9E35AB7B4D1DCF031C50502FA6F1CE270B6E334F8418CA61118523471A33`; diagnostic
  `730C5E366E45607DECFCBC4EE1D25F8CAA145B2DF841F13935DB381754D0186D`.
- After that build and documentation checkpoint, resume O8. Refresh adapter and commit
  telemetry; do not launch until the installation path is confirmed and the 12 GiB
  preflight passes. No gameplay or FPS data exists.

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

- Target: desktop RTX 3070 8 GB, Ryzen 7 7700X 8C/16T, 32 GiB RAM, Windows 11 Pro 26H2 build 26300.10075.
- Base: COOL_FOX Pareto-residency descendant through the NVIDIA 8 GB source subtree.
- Clean pinned Release and diagnostic builds passed after the current source patch; see
  O7 below for the build ID, toolchain, and hashes.
- No `VICTORY_GAME_DIR` is configured. A read-only check found two executables under the
  standard library root but could not confirm either as the authorized runtime. Do not
  launch until the user-selected directory is resolved and preflight passes.
- Hardware sample at 2026-11-27 03:47 CET reported 10.32 GiB available commit, below the
  12 GiB launch floor, and 11.92 GiB available physical RAM. These values are volatile;
  refresh immediately before any launch and never bypass the guard.
- Commit `7d7bbb8` hardens the launcher and benchmark preflight: the minimum is 12 GiB,
  can only be raised, and has no low-commit bypass. Follow-up `dfe5be8` delays warm-cache
  seed copying until after the commit gate. The shared PowerShell suite passes 15 cases,
  including all three entry points and the gate-before-copy ordering; this does not replace
  a fresh prelaunch sample.
- The RTX 3070 remains the first DXGI adapter; driver 610.88, PCIe Gen4 x16, SM 6.8,
  WaveOps 32, mesh shader tier 1, and ray-tracing tier 1.2 were reported. BAR1 suggests
  Resizable BAR but does not prove the firmware setting.
- Vice-Tay reference checkout is outside Git under
  `%LOCALAPPDATA%\AstraForge\references\Vice-Tay`, audited at `cc9ed86`.
- Current focused ports include placed-view descriptor canonicalization (Vice-Tay #27
  commits `f07e54a2` and `ce914907`), opt-in `VICTORY_FILL_TITLE=2` (commit `32a13f7`),
  and the first-piece shadow compare fix (Vice-Tay #114, local commit `abcb275`).
  `VICTORY_FILL_TITLE=2` remains disabled by all supplied profiles.
- Focused test results already obtained:
  - `placed_views_ignore`: 2 passed, 0 failed.
  - `descriptor::tests`: 10 passed, 0 failed.
  - `fill_title_mode_tests`: 3 passed, 0 failed.
- No runtime launch, image review, shader prewarm, or gameplay capture occurred. Do not
  infer rendering quality, runtime stability, or FPS from these tests or builds.

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

The latest source commit is `abcb2750a4c17349c44c1026394041682ed337f0`. Its clean build
is `20261127-042402-Both-thinlto-native-7e316a03`, with `SourceDirty=false`, Rust/Cargo
1.98.1, MSVC, DXC 10.0.26100.0, Thin LTO, and native CPU code generation. Both
executables return success for `--help`. SHA-256: Release
`E20A9E35AB7B4D1DCF031C50502FA6F1CE270B6E334F8418CA61118523471A33`; diagnostic
`730C5E366E45607DECFCBC4EE1D25F8CAA145B2DF841F13935DB381754D0186D`. The shadow
regression passes in debug and Release; the GPU library suite passes 346 tests with 34
ignored. None of these checks verifies actual rendering, memory pressure during gameplay,
stability, or FPS.

## Next exact task: O8 runtime readiness

Resolve the authorized installation directory and refresh hardware and commit-headroom
telemetry. The latest sample had 10.32 GiB available commit, below the 12 GiB
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
