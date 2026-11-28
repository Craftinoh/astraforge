# AstraForge — progress journal

This file is the durable task record. Update it when source, build, benchmark, hardware, publication, or user plans change.

## Publication sync - 2026-11-27

- Pushed source commit `abcb275` and verification/documentation commit `fe8df83` to `origin/main` with a fast-forward after confirming the remote head.
- After the push, local `main` and `origin/main` both resolved to `fe8df83499d81209b00db32e2043698d714b26a2`, and the worktree was clean. This publication-sync entry is a follow-up journal update.

## O8 readiness refresh - 2026-11-27 03:47 CET

- The hardware collector ran read-only and saved its raw report outside Git. It reported a Ryzen 7 7700X (8 physical / 16 logical), 32 GiB installed RAM, Windows 11 Pro 26H2 build 26300.10075, RTX 3070 as first DXGI adapter, driver 610.88, PCIe Gen4 x16, SM 6.8, WaveOps 32, mesh tier 1, and ray-tracing tier 1.2. BAR1 aperture suggests but does not prove Resizable BAR firmware state.
- Available physical RAM was 11.92 GiB and available commit 10.32 GiB, below the launcher's 12 GiB floor. Do not start the runtime until a fresh sample passes the guard.
- `VICTORY_GAME_DIR` is unset. A read-only scan of the standard library root found two executables, but neither was resolved to the authorized runtime. No installation path or executable was stored in Git, and no runtime was launched.
- Next: resolve the user's selected install directory, rerun hardware preflight, then proceed to shader prewarm and gameplay only when the 12 GiB commit gate passes.

## O8 commit-gate hardening - 2026-11-27

- Source commit `7d7bbb8` added `tools/AstraForge-Preflight.psm1` and routed both the launcher and gameplay measurement harness through its fail-closed commit check. The floor is 12 GiB and callers can only raise it; the `-AllowLowCommit` switch and below-12 threshold values are rejected.
- Follow-up source commit `dfe5be8` moved warm cache-seed cloning after the hardware and commit gate, preventing a low-headroom run from copying a potentially large seed before it is rejected.
- `tools/Test-AstraForgePreflight.ps1` passed 15 cases, including parameter-binding checks against all three entry points and a regression check for gate-before-copy ordering. PowerShell parsing passed for the changed script/module files, and the benchmark harness synthetic suite passed all six cases.
- `git diff --check` passed. The launcher has still not been run with a runtime executable; current telemetry remains below the floor and no frame, visual, stability, or FPS result exists.
- Next: resolve the authorized installation directory and obtain a fresh hardware report with at least 12 GiB available commit before any prewarm or runtime start.

## Current objective

Prepare AstraForge as a profile-driven Xbox compatibility layer. Start with NVIDIA RTX 3070 Ampere, target at least 30 real gameplay FPS with a 1% low of at least 30, and add AMD only in a later separately validated phase. Keep public benchmark reporting anonymous and do not identify the game title.

## Workspace and source

- Workspace: `workspace root`.
- Main workspace is a Git repository on branch `main`, with the public remote configured.
- The NVIDIA source is imported at `third_party\nvidia-3070-VI` as a Git subtree, so its patch history remains reachable without a nested Git link.
- Imported source HEAD: `e31aafd` (`docs: anonymize title-specific source comments`), following launcher commit `c6f1fc4`.
- Source baseline: NVIDIA 8 GB derivative at `6e9c1dd9fb32daaa855f446560a4d1f8df5f8424`, descended from COOL_FOX Pareto-residency reference `f4b48ad766ddbec1a1867022cd42f7645b0dd55e`.
- Source license: GPL-3.0. Local patch provenance is in `docs/source-credits.md` and the nested source `LOCAL-CHANGES.md`.
- Root profile files: `profiles\rtx3070-profiles.json`; the new `profiles\gpu-profiles.json` currently describes only RTX 3070.

## Baseline host snapshot — 2026-11-26

Captured 2026-11-26 21:44 CET. RTX 3070 is the first DXGI adapter, device `10DE:2484`, D3D12 shader model 6.8, WaveOps with 32 lanes, PCIe Gen4 x16, NVIDIA driver 610.88. CPU is Ryzen 7 7700X, 8 physical / 16 logical cores, AVX2. RAM is 32 GiB; available physical memory was 15.49 GiB and available commit 14.95 GiB. DIMM speed was not exposed by the accessible CIM/SMBIOS query; DDR5-6000 CL36 remains user-reported. ReBAR is inferred from BAR1 size, not directly verified.

Raw hardware reports are local under `out\` and must not be published. A refreshed capture should be taken before real benchmark runs.

## Source patches already committed

1. `fe8995b`: Clippy precedence correction, behavior-preserving.
2. `2374bca`: documentation sync to latest available NVIDIA fork notes.
3. `f0ab013`: DirectStorage worker count uses physical cores with a bounded override; origin fxceless #1044.
4. `878dbd7`: descriptor dynamic ranges retain allocating heap identity; origin fxceless #1324, includes regression test.
5. `6e91b7b`: defer descriptor nulling/resource release while GPU submissions are in flight; origin `victory-unified@768735a`, includes regression test.
6. `afbb784`: replace the copied launcher example data path with a neutral `GameFiles` directory; personal files remain external.
7. `337310f`: accept the local game executable through `VICTORY_GAME_EXE`, defaulting to a generic filename.
8. `c6f1fc4`: move the copied launcher's default data folder to `%LOCALAPPDATA%` so it cannot land inside the project workspace.
9. `e31aafd`: anonymize title-specific source comments and examples without changing runtime behavior.
10. `468b79b`: correct two indirect-budget test fixtures without changing runtime shader behavior.
11. `f8b6af5`: reserve the portable heap's null sentinel before the 2^18 dynamic descriptor tail; adds a no-overlap regression test.
12. `42435bf`: start commit-headroom admission at zero until Windows provides a valid sample.

At the time of the initial import, the pinned Rust/MSVC/DXC toolchain was unavailable. The current source has since passed the pinned Windows build and GPU-library tests recorded below.

## Workspace tooling and evidence

- Hardware probe and current host report: `tools\Collect-AstraForgeHardware.ps1`, `out\hardware-latest.json`.
- Four RTX tuning candidates: Stability, Balanced, Performance, Quality. They differ by `VICTORY_TEXTURE_ROOM_PERCENT` and have not been measured locally.
- Build helper: `tools\Build-AstraForge.ps1`; it now creates a unique external Cargo target/artifact directory and records hashes. Thin LTO + native CPU is the Ryzen 7 7700X candidate build.
- Runtime launch: `tools\Start-AstraForge.ps1` reads `profiles\gpu-profiles.json`; the RTX 3070 wrapper remains available as `tools\Start-AstraForge3070.ps1`. The profile-file path bug is fixed, and adapter, D3D12, wave-width, compute-capability, dedicated-memory, and commit checks are manifest-driven.
- Shader prewarm: `tools\Prewarm-AstraForge.ps1`; it accepts an isolated cache seed and writes a fingerprint manifest.
- Gameplay capture: `tools\Measure-AstraForgeGameplay.ps1`; comparison: `tools\Compare-AstraForgeRuns.ps1`; cache functions: `tools\AstraForge-BenchmarkCommon.psm1`.
- Synthetic test command: `tools\Test-AstraForgeBenchmarkHarness.ps1`. The latest run passed cache seed cloning/mutation detection, three-run cold/warm comparisons, target evaluation, anonymous report export without local paths, and rejection of mismatched warm seeds and unclassified frames. All ten PowerShell scripts/modules parsed successfully after the GPU-profile refactor.
- The clean-source optimized Release and diagnostic builds completed from commit `fd423c7`. Shader prewarm and gameplay captures have not been run. No local FPS result exists.

## Performance evidence and target risk

The closest 8 GB NVIDIA source report measured about 17 FPS (58.2–59.4 ms/frame) on a different RTX 3070 Ti system. Its submitting CPU thread measured 55.9 ms while the GPU was about 64% busy, with roughly 21 ms idle behind submission. That points to a CPU-side submission bottleneck on that host. This system's Ryzen 7 7700X differs, so the result is not a prediction. Thin LTO, native CPU code generation, and PSO prewarming are candidates; each requires an A/B gameplay capture. The 30 FPS goal remains unverified.

## Current blockers and user update

- The game directory remains unset. When local files become available, inspect the installation for a compatible executable and keep all personal data outside the repository.
- Rust 1.98.1, the Windows MSVC linker, DXC, and PresentMon are installed. The RTX 3070 remains the first DXGI adapter; gameplay compatibility and captures are still pending.
- The public remote is live on branch `main`; keep account names and local machine paths out of published documentation.

## Publication and privacy rules

- Do not name the game title in public project documentation or benchmark reports.
- Public route labels must be neutral, e.g. `scene-01`; omit executable names, title identifiers, save IDs, user paths, raw logs, and account names.
- Keep game files, caches, saves, raw hardware reports, and generated executables outside version control.
- Retain all original source notices, GPL-3.0 license terms, and upstream commit/PR credits.
- The intended project direction is NVIDIA-first with data-driven GPU profiles; do not add AMD tuning until its adapter selection and validation are implemented.

## Next actions

1. Run the guarded profile and shader-prewarm preflights against the final clean-source artifact once the game directory is available.
2. The user reports OP Coding is healthy behind a local-only API key. No inference has been sent from this workspace; keep the endpoint and key private and validate that integration only when explicitly requested.
3. Once the local game directory is ready, capture repeatable cold/warm gameplay cohorts, inspect rendering, and report measured memory and frame-time behavior.
4. Add later GPU profiles only with hardware checks, source attribution, rollback notes, and repeated correctness/performance evidence.
## 2026-11-26 — GPU profile and public-report update

- Generalized gameplay measurement metadata to include the selected `GpuProfile` and adapter LUID; cohort comparisons now require the same GPU profile and adapter identity.
- The benchmark harness and shader prewarm helper now load the hardware-profile manifest. Working cache/data defaults are namespaced by GPU profile; NVIDIA is still the only implemented entry.
- Added `tools/Export-AstraForgePublicReport.ps1`, which rebuilds a shareable report from an allowlist and omits local capture/cache paths, raw telemetry, and executable names. The synthetic harness confirms that path fields are absent.
- Updated the benchmark and launcher documentation, source/privacy policy, and rollback inventory. Anonymous scene labels are enforced at capture and export time.
- PowerShell parser and synthetic benchmark tests pass after these changes. No Rust build, game launch, shader prewarm, visual review, or real gameplay measurement has occurred.
- Git 2.56.1 and GitHub CLI 2.106.0 are present and authenticated. The public repository has been created; the reviewed local tree contains no tracked game data, captures, binaries, personal paths, account names, or credentials.

## 2026-11-26 — public repository preparation

- Converted the workspace into a `main` Git repository and imported the NVIDIA source as a subtree while preserving all source commits through `e31aafd`.
- Verified that the subtree is stored as normal files rather than a gitlink, and that `e31aafd` is reachable from the project history.
- Scanned tracked files for personal paths, credentials, game/capture/binary paths, and prohibited public title/publisher strings; none remain in the current tree.
- Created and published the public GitHub repository; `main` and the local branch both pointed to `f436e04` after the first push.

## 2026-11-26 — integration architecture and delegated review

- Added `docs/integration-architecture.md` to define the source-patch, GPU-profile, runtime-preset, build, benchmark, provenance, and rollback contracts used by AstraForge.
- Public presentation now states the scoped differentiator supported by the reviewed fork set: AstraForge is the only reviewed project organized primarily around fast, repeatable integration by contributors.
- A previous model-assisted descriptor-lifetime review proposed race/deadlock blockers. Manual source tracing confirmed `flush_unmake` holds the per-slot `Made` lock across the state check and drops the queue mutex before `unmake_key`; those findings were not treated as defects without supporting evidence.
- At that time, Rustup, MSVC, DXC, PresentMon, builds, and gameplay validation remained pending; the toolchain and builds were completed on 2026-11-27.

## 2026-11-27 — local validation and Ampere correctness fixes

- Fixed a descriptor-range overlap identified in a model-assisted review and confirmed independently: the portable one-million-view heap now keeps the shader null-clamp slot immediately before a fixed 2^18 dynamic-descriptor tail. Title descriptor mirrors are capped before that sentinel. A unit test checks that the title, null, and dynamic ranges cannot overlap.
- Made host commit-headroom admission fail closed until the first valid `GlobalMemoryStatusEx` sample. A failed initial sample can no longer be interpreted as unlimited available commit.
- Corrected two indirect-budget test fixtures: the host test now leaves too little budget for its follow-up dispatch, and the WARP assertion counts only accepted jobs. Runtime shader logic was unchanged by these test corrections.
- `cargo test --locked -p victory-gpu --lib -- --test-threads=1`: 340 passed, 0 failed, 34 ignored. The full `cargo test --locked --workspace -- --test-threads=1` run also passed: 934 passed, 0 failed, 47 ignored, including 281 shader-translator tests. Both runs include D3D12/WARP coverage; they validate unit behavior, not gameplay.
- Final clean-source build: ID `20261127-005831-Both-thinlto-native-c8d108a7`, source commit `fd423c7a851e743b17baa43fb8414cc2049f1b4d`, `SourceDirty=false`. It used Rust/Cargo 1.98.1, Windows MSVC 14.44.35207, DXC, Thin LTO, one release codegen unit, and `-C target-cpu=native`. Artifacts and SHA-256 hashes are recorded in the external build manifest under `%LOCALAPPDATA%\AstraForge\builds\artifacts\<build-id>\build-manifest.json`; Release is 9,912,320 bytes (`58748A7EF47229D41DAD8F3934407DDAE83F2B538A0624313B72134B0DACD5DA`), diagnostic is 19,179,520 bytes (`4CEB6525952B27FC012E1E20E8E3E0D21954A87E73B430E140EBB705AF5C3160`). Both binaries return success for `--help`. Compilation succeeded with existing warnings in the imported GPU crate; there were no build errors.
- The earlier dirty-source artifact remains outside the repository and is superseded by the clean build above.
- The documentation, source-credit, and validation update was pushed to public `main`; `origin/main` matched commit `5176512` and the worktree was clean at verification. Binaries, build manifests, and raw logs remain outside the repository.
- No game launch, shader prewarm, visual review, or gameplay benchmark has occurred. No FPS or performance gain is claimed.

## 2026-11-27 — contributor and AI-agent onboarding

- Added root `AGENTS.md` with the project scope, source and privacy constraints, validation workflow, provenance requirements, and completion-report format for coding agents.
- Added `CONTRIBUTING.md`, `docs/AI_CONTRIBUTOR_GUIDE.md`, and `docs/GPU_PROFILE_SUBMISSION.md` to explain the repository map, safe model-assisted workflow, evidence levels, hardware-profile gate, and the current first-DXGI-adapter limitation.
- Added sanitized hardware-report and reusable model-task templates under `docs/templates/`, plus a GitHub pull-request checklist for source origin, validation, rollback, and privacy review.
- Updated the README with contributor entry points. The documented gates explicitly distinguish a hardware inventory from enabled GPU support and distinguish build/unit evidence from gameplay performance evidence.
- Documentation-only changes; no runtime code or tuning values changed. Both GPU profile JSON files parse, all relative links in the onboarding docs resolve, `git diff --check` passes, and a focused scan found no API key/service endpoint, local account path, or prohibited title/publisher identifier in the new public material. `Test-AstraForgeBenchmarkHarness.ps1` passed all six synthetic checks when run in a PowerShell process with execution-policy bypass; the machine's default policy blocks direct script invocation. These synthetic checks do not establish gameplay performance or GPU compatibility.

## 2026-11-27 — per-machine contributor handoff

- Added `docs/CONTRIBUTOR_HANDOFF.md` to define a practical clone → local hardware inventory → isolated profile experiment → sanitized pull request workflow, with separate responsibilities for the hardware contributor, shader/engine maintainer, and coding model.
- Linked the handoff from the README and `CONTRIBUTING.md`. It explicitly warns that the current renderer selects the first DXGI adapter and that a manifest entry alone does not enable a new GPU.
- No engine or profile code changed. Runtime work remains limited by the unset local game directory and, at the latest hardware sample, 10.05 GiB of available commit against the launcher's 12 GiB preflight floor. The sample is transient and should be refreshed before any gameplay run.

## 2026-11-27 — hardware refresh and render-path audit

- Refreshed the local ignored hardware capture with DxDiag. RTX 3070 (`10DE:2484`) remains the first DXGI adapter; driver 610.88, PCIe Gen4 x16, Shader Model 6.8, WaveOps 32, feature level 12_2, mesh shader tier 1, sampler feedback tier 0.9, and ray-tracing tier 1.2 were reported. These feature tiers do not prove translated-title compatibility.
- The capture reports 32 GiB installed and 31.1 GiB usable RAM. CIM/SMBIOS reports DIMM configured clocks of 4800 MHz although the module identifier corresponds to the user-reported DDR5-6000 kit; effective in-use memory speed remains to be confirmed independently.
- At 2026-11-27 01:23 CET, Windows reported 10.05 GiB available commit, below the launcher's default 12 GiB preflight floor. `nvidia-smi` reported 1,660 MiB used and 6,358 MiB free globally; this is desktop-wide and not per-process title residency. DXGI reported 7,249 MiB budget for the collector process, which is not the eventual renderer process budget.
- Source audit confirms runtime code already queries the renderer's own `IDXGIAdapter3` local/non-local budgets and adapts title-buffer residency to local DXGI budget. The current presenter obtains swap-chain dimensions from the title's presented resource. Its two-plane compositor scales planes during composition, but there is no verified independent 1280x720 internal render control or separately configured 1920x1080 output path.
- The raw hardware and DxDiag files stay under ignored `out/`; they are not published. No game directory was configured, so no launch or gameplay measurement was attempted.

## 2026-11-27 — workspace lint audit

- Ran the repository-pinned `cargo clippy --locked --workspace --all-targets --message-format=short` against the imported source using the external build target directory. Clippy exited successfully with warnings, not errors.
- Remaining warnings span redundant `drop(Copy)` expressions, an unannotated function-pointer transmute, precedence/style suggestions, dead diagnostic/test helpers, and a large enum layout. No blanket `cargo clippy --fix` was run; each warning needs call-path and behavior review before changing upstream source.
- Rechecked the existing Release and diagnostic executable hashes and Release `--help`; both artifacts remain available outside Git. These checks do not add gameplay, image-quality, or FPS evidence.

## 2026-11-27 — runtime readiness and model-review tooling

- Refreshed the ignored local hardware report at 01:40 CET. The RTX 3070 remains the first DXGI adapter and reported 1,635 MiB used / 6,383 MiB free globally. Windows reported 11.95 GiB available physical RAM and 9.32 GiB available commit, still below the launcher's 12 GiB floor. The figures are volatile and must be sampled again before launch.
- Inspected the standard Xbox game-library directory read-only. It currently contains service/save material and a separate launcher, but no executable for the authorized test application. Gameplay launch, shader prewarm, visual validation, and performance measurement therefore remain pending installation completion.
- Verified the configured remote OpenAI-compatible coding endpoint without exposing its credential; a minimal Chat Completions request returned the requested handshake. This proves connectivity and authorization only.
- At the user's direction, use the configured API directly for delegated read-only reviews. The API key and review outputs remain outside the repository.
- Added `tools/Invoke-AstraForgeModelReview.ps1` and `docs/MODEL_ORCHESTRATION.md`. The wrapper accepts explicit text inputs, rejects common generated/private/credential paths, enforces per-file and complete-request size ceilings, reads credentials from environment variables, and writes model responses outside Git. Its parser, bounded dry run, and live review completed successfully; oversized/output-heavy requests returned HTTP 422 and led to a 450 KiB request ceiling and 4,096-token default.
- Added `docs/OPERATIONAL_PLAN.md` as the durable execution queue. It records current evidence, Vice-Tay audit order, source/build/runtime gates, benchmark sequence, and resume instructions. Vice-Tay remains a selective donor candidate; no source patch from it has been integrated yet.

## 2026-11-27 — placed-view shape canonicalization

- Fixed the Vice-Tay donor revision at `cc9ed86` and reviewed its #27 placed-view leak evidence. The selected AstraForge base copied all resource and view-description words into each placed shape, including resource padding, SRV padding, and dimension-unused union tails. Those unwritten values could consume the 2^22 shape namespace and send later views to the persistent table-entry fallback.
- Used the configured remote coding model for a bounded read-only review (`chatcmpl-b1dadf6286419569`). It correctly highlighted the uncanonicalized key but incorrectly claimed that the local `SHAPES` limit was absent. Direct source tracing confirmed the existing 2^22 bound and rejected that model claim.
- Ported only descriptor canonicalization from Vice-Tay #27 focused commits `f07e54a2` and `ce914907`, retaining the earlier `JMAN730/project-flamingo@b1e0cd1d` credit for resource padding. The separate ownerless-entry cap and unrelated shader/list/ambient changes remain unported.
- `cargo test --locked -p victory-gpu --lib placed_views_ignore -- --test-threads=1 --nocapture`: 2 passed. `cargo test --locked -p victory-gpu --lib descriptor::tests -- --test-threads=1`: 10 passed. Existing warnings remain. These tests validate descriptor key behavior only; they do not establish gameplay memory reduction, image correctness, stability, or FPS.

## 2026-11-27 — O4 shadow/resource lock audit

- Changed `tools/Invoke-AstraForgeModelReview.ps1` to use the provider-neutral `ASTRAFORGE_MODEL_API_KEY`, load endpoint/model settings from the current user's environment when they are absent from the process, and send selected inclusive source line windows with original line numbers. Dry runs no longer print the configured model or endpoint. Migrated the local user credential setting to the generic variable without printing its value; the credential remains outside Git.
- PowerShell parser check passed. Matching bounded dry runs stayed under 21 KB at 4,096 output tokens; both live read-only reviews completed and were saved outside Git: `chatcmpl-9685cbb031a1f6d9` and `chatcmpl-920314fe942fcf73`.
- Local path: `draw::readable` → `descriptor::host::buffer_copy` → `view_home` → `shadow::exact`. `view_home` first requires the start address to lie inside the current shadow. With `VICTORY_VIEW_BYTES` enabled, raw views reach `exact` when not 16-byte aligned, structured views when not aligned to either 16 bytes or stride, and typed views when not element aligned. It is not restricted to structured views. No `VICTORY_STRUCTURED_RAW` setting exists in this source tree.
- Manual audit found `EXACT`'s global mutex held across cache lookup/retention, `host.shared_buffer` (`CreateCommittedResource`, residency, and mapping), resource naming, `Shadow` construction (including a page bitmap allocation), and insertion. There is no byte copy in `exact`; `Shadow::refresh` later defers the `Arc` and range to the list, whose refresh copies the requested data. Eviction uses recency plus `Arc` and COM reference counts; descriptor resources and list steps keep the copy alive.
- The first review proposed copying the donor's `VICTORY_STRUCTURED_RAW` gate despite its absence locally, and projected the donor's per-frame call counts onto this path without local evidence. The second correctly found the mutex but overclaimed several `Mutex::default` fields as heap allocations and blurred buffer creation with byte copying. These claims were checked against source. Vice-Tay #37 reports a measured RTX 4090 bottleneck in a different merge; it is a useful hypothesis, not a local RTX 3070 result.
- No source optimization was justified from the available evidence. Do not copy the donor gate: `VICTORY_VIEW_BYTES=0` restores null views for affected ranges and may remove required data. A lock-scope change must prevent duplicate resource allocations and preserve cache, COM descriptor, and in-flight list lifetimes. Existing `EXACT_STATS` logs requests and allocations per frame but not lock wait; collect those counters and a CPU contention profile during real gameplay before choosing a design.
- No game launch or gameplay measurement occurred. Runtime readiness and commit headroom remain volatile; no FPS, stability, visual, or memory improvement is claimed from this audit.

## 2026-11-27 — O5 Wave32, NaN, and ray-path audit

- Extended `tools/Invoke-AstraForgeModelReview.ps1` so explicitly ranged source files up to 4 MiB can be excerpted; whole-file inputs remain capped at 512 KiB and only selected lines are sent. PowerShell parser and dry-run checks passed. A wave review of four local excerpts sent 16,579 bytes; a NaN/BVH review of six excerpts sent 32,625 bytes. Both live reviews were saved outside Git (`chatcmpl-8dbf8276f41e3d0f`, `chatcmpl-961795fe29590bee`).
- Source trace: D3D12 host creation queries `D3D12_FEATURE_D3D12_OPTIONS1.WaveLaneCountMax` and supplies it to shader lowering. The host wave value is part of the shader cache identity; the cache also keys `VICTORY_WAVE_WIDE`, `VICTORY_WAVE_DEEP_SKIPS`, and `VICTORY_WAVE_LOCAL`. The runtime uses retries for guest wave64 compute on host wave32: early-out/skip variants, guarded wave-wide barriers where allowed, and local-wave lowering. Some local fallback is explicitly approximate; `VICTORY_WAVE_LOCAL=idiom` keeps only the exact local idiom. `VICTORY_WAVE_WIDE=1` broadens eligible retries and is not a safe blanket performance switch; source comments retain a prior device-loss case. The 3070 profile leaves these wave switches unset.
- No runtime `VICTORY_NAN_SCRUB` reader exists. The optimizer preserves NaN-sensitive float semantics and the custom software BVH handles NaNs at specific operations. The translated ray-node operation is software-emulated in DXIL; unsupported return modes are refused with explicit errors. No global ray-disable setting is implemented, so no shader or ray work was removed.
- Review responses were not trusted: the wave response incorrectly claimed the 32-lane fallback always fails despite the retries in `emit/mod.rs`; the NaN response misattributed a box-bound check to triangle code. Independent source tracing rejected those claims.
- With pinned Cargo 1.98.1, `cargo test --locked -p victory-shader --lib -- --test-threads=1` passed 281, failed 0, ignored 4 in 251.57 s. The targeted `cargo test --locked -p victory-shader --lib emit::intersect_tests::the_64_bit_node_test_in_a_host_buffer_matches_the_reference_on_the_card -- --test-threads=1 --nocapture` passed 1/1 in 0.65 s; output contained no hardware or WARP skip notice. Cargo initially wrote 571 generated files (391.8 MiB) to the imported source's `target` directory because `CARGO_TARGET_DIR` was not set; that directory was immediately cleaned. Set `CARGO_TARGET_DIR` to an external cache before future Cargo builds/tests. These checks exercise synthetic shader/reference cases on the available adapters only.
- No shader source patch was justified. There is no actual-game screenshot, visual inspection, ray-path coverage, or gameplay measurement yet; no graphics-quality or FPS claim follows from the tests.

## 2026-11-27 — O6 static residency and texture-pressure audit

- Traced DXGI memory reporting in `Host::video_memory` and `video_memory_groups`: both process-local and non-local budget/usage are queried from the active adapter, with dynamic local budget changes logged. The texture pass does not assume an 8 GiB physical allocation is fully available to this process.
- Traced texture-copy admission in `resource::room`: it uses a budget-scaled floor capped at one quarter of local DXGI budget, subtracts reusable free texture-pool capacity from current usage, and accounts for shadow and render-target headroom before the default 90% ceiling (override clamped to 50-97%). `VICTORY_TEXTURE_BUDGET_MB` replaces this dynamic share with an explicit host-copy byte cap; profiles leave it unset.
- Traced per-frame staging in `draw::heap_textures`: 8 GiB local budget maps to 192 MiB/250 ms by default; hosts at or below 32 GiB physical RAM get a 128 MiB default before backlog catch-up. Pressure limits automatic prefetch to 64 MiB, critical commit pressure to 16 MiB, and the <=32 GiB host uses the 64 MiB limit after live staging reaches 1 GiB. Before admitting each new non-bake texture slot, code checks for 512 MiB available commit; speculative upload-pool growth keeps 1 GiB. E_OUTOFMEMORY backs off new uploads for 500 ms.
- `VICTORY_TEXTURE_STAGE_MB` is an explicit override to the automatic byte ceiling and bypasses `prefetch_limit`; dynamic VRAM room and per-pass commit admission remain active. No supplied profile sets it. Large values are not recommended before matched pressure tests. Idle staging ownership is released only when no command list retains it and the dynamic idle threshold expires; pooled blocks only release after every piece returns and the 2.5 s rest interval.
- Two read-only model reviews (`chatcmpl-acbdf85696c4200b`, `chatcmpl-959580779bf7701b`) were manually checked. Suggestions to strengthen relaxed atomics, claims of staging use-after-free/leaks and initialization-order defects, and the `VICTORY_HEAP_TEXTURES=0` RAM-guard claim were unsupported by the call paths. The `room_lately` 100 ms memoization is an explicit DXGI query amortization. One practical configuration caveat was confirmed: a manual `VICTORY_TEXTURE_STAGE_MB` value opts out of the automatic pressure byte clamp.
- No source change is justified from static review alone. Runtime DXGI usage, staging growth, queued textures/misses, commit headroom, artifact checks, and device-loss behavior still require gameplay installation and matched captures. No FPS, visual-quality, or stability result is claimed.

## 2026-11-27 — O2 selective donor audit and conservative fill-wait mode

- Completed the selected PR #37 follow-up against donor snapshot `cc9ed86`. The opt-in upload copy queue stages shadow/card-buffer writes through a device-local bounce buffer and a cross-queue fence. Its retained slots have no idle trim and can retain up to 512 MiB each; its queue-signal and CPU-wait error paths need additional device-loss handling before any port. The donor's 21.6 to 22.7 median-FPS comparison is a broad cumulative merge; private memory and peak card memory both rose substantially, so it does not isolate queue benefit or support an 8 GB RTX 3070 recommendation.
- Rejected the donor texture store for this target: it restores mip levels from disk and does not lower VRAM demand; files are never trimmed, its job channel is unbounded, and each queued job copies the full tiled texture. Its nominal 4 GiB RAM cache is not a strict reservation under concurrent loads. No texture-store code was ported.
- Reviewed the donor's `lane_uniform` Wave32 shader proof. It expands translation of three structure-builder programs in the donor's report, but the same report says that opt-in builder still crashes during a world run. It is not a demonstrated gameplay optimization and remains unported.
- Ported only the conservative `VICTORY_FILL_TITLE=2` predicate from [`TaynanGT/Vice-Tay@b6be7e3`](https://github.com/TaynanGT/Vice-Tay/commit/b6be7e3b0b2f7ead75ff999ae53e3021da17c7cb), commit `32a13f7`. Existing mode `1` behavior is preserved; mode `2` bypasses the wait only when `watch::landed_lately` reports no shader write landed in the range for 600 frames. The unset default and all four supplied profiles remain unchanged. The donor reported a short-scene frametime improvement, but that is not RTX 3070 evidence.
- `cargo test --locked -p victory-gpu --lib fill_title_mode_tests -- --test-threads=1` passed 3/3 (376 filtered). The changed block has no rustfmt diff; whole-file `rustfmt --check` reports pre-existing formatting differences outside the changed helper/tests in imported `host.rs`.
- `tools/Build-AstraForge.ps1 -Mode Both -ThinLto -NativeCpu` passed from a clean checkout. Build ID: `20261127-033517-Both-thinlto-native-5aaf5812`; manifest source commit `960828f7eb1c141be2176e17fe09abd9e7c0650b`, `SourceDirty=false`; Rust/Cargo 1.98.1, target `x86_64-pc-windows-msvc`, DXC 10.0.26100.0. Both Release and diagnostic executables returned success for `--help`. SHA-256: Release `F172EF1C49219FC8A093EB0392ACC96FD98AF77390823E6B9CA2AC4D1C2A392E`; Diagnostic `1931A334F428B646F107FC067DCA6DC78FA20C3DD0BE30959AD28B01FB0F6A42`.
- The bounded UP_QUEUE model review (`chatcmpl-af131c61fafec10b`) falsely claimed a shader-descriptor transition was missing and that `make_queue` reacquired `QUEUE`. Manual tracing rejected both; the bounce resource is used by copies, and the queue-construction closure does not recursively lock the mutex. The review output remains untrusted and outside Git.
- No local game runtime, image review, shader warmup, or gameplay capture occurred. No FPS, visual-correctness, runtime-stability, or 30 FPS claim follows from this source audit or predicate tests.

## 2026-11-27 - first partial shadow-piece correction

- Refreshed the NVIDIA donor through read-only GitHub API: default-branch snapshot `123c4b7`, after combined merge `0ef44bc` / PR #116. PR #116 includes PR #114, but its eight-sample opening-scene comparison has different draw counts and pipeline queue depth; it is not an isolated patch result. The local reference clone remains at `cc9ed86` because Git transport previously failed DNS.
- Audited Vice-Tay #114's exact `Shadow::differing` cut against the selected source. The old `at - (start + at) % PIECE` underflowed when the first cut began at offset zero and the title base was 32 KiB into a 64 KiB piece. In debug, the new test reproduced the arithmetic-overflow panic at `shadow.rs:3374`; in optimized code that wrapped cut could skip the first worker's entire slice.
- Ported the one-expression saturating-subtraction correction and added `parallel_compare_includes_the_first_partial_piece`, a synthetic 48 MiB case requiring every changed byte to be included and every returned piece to end on a 64 KiB title boundary or the range end. Provenance is recorded in `source-credits.md` and subtree `LOCAL-CHANGES.md`: Vice-Tay #114, adapted from fxceless #1407, original finding credited to Kelvaroq's `stellarr-studio/kelvaroq` patch 0009.
- Focused verification: the regression failed before the patch as expected; after it, debug and optimized Release each passed 1/1. Full `cargo test --locked -p victory-gpu --lib -- --test-threads=1` passed 346, failed 0, ignored 34. It exercises synthetic/library behavior, not a gameplay route.
- Whole-file `rustfmt --check --edition 2024 crates/victory-gpu/src/shadow.rs` reports broad pre-existing formatting differences across the imported file; the newly added test block has no rustfmt diff. The file was not reformatted wholesale to avoid an unrelated source churn.
- `git diff --check` passes. Clean pinned Release and diagnostic builds completed from commit `abcb2750a4c17349c44c1026394041682ed337f0` with `SourceDirty=false`: build ID `20261127-042402-Both-thinlto-native-7e316a03`; Rust/Cargo 1.98.1, MSVC, DXC 10.0.26100.0, Thin LTO, native CPU. Both executables returned success for `--help`. SHA-256: Release `E20A9E35AB7B4D1DCF031C50502FA6F1CE270B6E334F8418CA61118523471A33`; diagnostic `730C5E366E45607DECFCBC4EE1D25F8CAA145B2DF841F13935DB381754D0186D`.
- No device run, visual validation, runtime-memory result, FPS gain, or stability claim is made. Next: return to O8 runtime readiness and refresh the 12 GiB commit gate before any launch.

## 2026-11-27 - per-heap decoration-bake coverage

- Rechecked Vice-Tay PR #85 against the local source. GitHub shows it merged on 2026-11-27 as commit `7eef143`; it replaces process-global bake coverage with queue-local revisions, guards overlapping texture passes, and refuses to certify truncated current/lookahead snapshots. Adapted this narrow change only; no combined fork merge was taken.
- The local `BAKE_SERVED` marker compared one process-global value against independent per-`HostHeap` texture write counters. Equal queue counts could therefore make an exact bake on one heap skip the other heap's pending textures when no shared memory note was pending. Replaced it with per-queue revision coverage; actual GPU-path coverage is recorded only after synchronous command execution and descriptor publication. Queue mutations and new/overlapping passes invalidate the prior token.
- Independently checked the bounded review (`chatcmpl-9641335141b65c57`): its concern that `TextureQueue::due(max)` should not cap results was rejected because the local API explicitly promises an up-to-`max` scheduling snapshot. The port uses the existing census only to withhold completion certification when that snapshot is shorter than the full due count; it does not change queue scheduling.
- Added regressions for equal revision values on separate heaps, stale revisions after a slot rewrite, overlapping passes, and a 65,536-entry snapshot with an additional due slot. The full diagnostic suite passed serially: 407 passed, 0 failed, 35 ignored. The optimized Release suite passed serially: 349 passed, 0 failed, 34 ignored. `cargo clippy -p victory-gpu --all-targets --features diagnostics` exited successfully with repository warnings outside the changed code.
- Parallel test execution was unstable: one diagnostic-feature run exited with `0xc0000005` after test output, and a later non-diagnostic run reported a panic in `texture::ahead::tests::a_placed_texture_is_filled_ahead_of_the_lists`. The serial diagnostic and optimized Release suites both pass; the concurrent test failure is recorded rather than attributed to this patch. The added queue tests do not invoke the GPU/runtime texture-ahead path.
- Whole-file `rustfmt --check` on `descriptor/host.rs` and `draw.rs` reports thousands of pre-existing style differences in this imported source. No broad reformat was applied. `git diff --check` passed before the focused commit.
- Clean pinned Release and diagnostic builds passed from `452e65527dca0fcc637e9e7f8f877a2a96b34a93`: build ID `20261127-050134-Both-thinlto-native-a19ebb64`, `SourceDirty=false`; Rust/Cargo 1.98.1, target `x86_64-pc-windows-msvc`, MSVC 14.44.35207, DXC 10.0.26100.0, Thin LTO, one release codegen unit, and `-C target-cpu=native`. Both executables returned exit code 0 for `--help`. SHA-256: Release `3EB0056B17F2BEDD35EDE5A7D5B0700C3B3BFABFDD34234C46D5A02CA22CE57A`; diagnostic `11A7076EACB9CF0BA1A7D05CF31FAD52702C56DB5442DED01DB7C2C4C39701BB`. The binaries and manifest remain outside Git.
- Published source commit `452e655` and build-evidence documentation commit `c7c244f` to `origin/main` by fast-forward. Remote `main` resolves to `c7c244f4e2466704f8dd4f50e625c55fc62f63b8`; local `main` matched it at verification. The feature branch remains available locally.
- No gameplay run, image inspection, device-loss stress test, memory-pressure capture, or frame measurement occurred. This is source/build correctness evidence only; no FPS, stability, or graphics-quality gain is claimed. Next: resume runtime readiness O8 only if the external install path is confirmed and a fresh commit-headroom sample passes the 12 GiB gate.

## 2026-11-27 - O4 exact-view cache contention observability

- Added diagnostics-only acquisition telemetry around the process-wide exact-view cache mutex. It counts only `try_lock` attempts that actually find the mutex busy, then records the blocked wait duration, maximum, and six bounded buckets (`<1 us`, `1-5 us`, `5-20 us`, `20-100 us`, `0.1-1 ms`, `>=1 ms`). Existing exact-view request and allocation counters remain in the frame line. Release builds use the original blocking lock path without timestamps or extra timing atomics.
- Added a bucket-boundary regression test. `cargo test --locked -p victory-gpu --lib --features diagnostics -- --test-threads=1` passed 408, failed 0, ignored 35. `cargo clippy --locked -p victory-gpu --all-targets --features diagnostics` exited 0; existing warnings remain in unrelated code, and the modified lines introduced no Clippy warning.
- Clean Release and diagnostic application builds passed from commit `f0c57bb6f6c9a0083ba7781592bd3747b8ee1c0a`: build ID `20261127-053816-Both-thinlto-native-ee1e228c`, `SourceDirty=false`; Rust/Cargo 1.98.1, target `x86_64-pc-windows-msvc`, MSVC 14.44.35207, DXC 10.0.26100.0, Thin LTO, one Release codegen unit, and `-C target-cpu=native`. Both `--help` checks returned 0. SHA-256: Release `9E04D58DCD83C66B82B541E6CAF5EC188C5A8905E7ED730426A6283A0E8EAAB6`; diagnostic `8DC38F48F84EC2E1924F53FCE155585589A59BC81E77540342C84BBD5AF7104D`. Artifacts and manifest remain outside Git.
- Refreshed hardware at 05:44 CET: RTX 3070 is first DXGI adapter, driver 610.88, SM 6.8, WaveOps with 32-lane min/max, PCIe Gen4 x16, Ryzen 7 7700X (8C/16T), 32 GiB installed RAM, 11.04 GiB available physical RAM, and 9.80 GiB available commit. Windows reports D3D12 mesh shader tier 1, sampler feedback tier 0.9, and ray tracing tier 1.2. The 7249 MiB DXGI budget is from the probe process and must not be mistaken for the runtime's budget. BAR1 aperture only suggests ReBAR; it is not a direct firmware query.
- `VICTORY_GAME_DIR` and `VICTORY_GAME_EXE` remain unset. The Xbox library root has executable candidates, but no authorized runtime was confirmed. The 9.80 GiB commit sample fails the 12 GiB launch floor, so no launch, shader prewarm, or gameplay capture occurred. Refresh commit telemetry and confirm the external installation path before trying O8 again.
- Published O4 source commit `f0c57bb` and build-verification documentation commit `941338f` to `origin/main` by fast-forward. A subsequent fetch confirmed `main` and `origin/main` both resolved to `941338fcbaae13cdcb6fc60408e5c7e7ef0365ad`; the working tree was clean at verification.
- Resolution path audit: `dxgi::display_size` reads `VICTORY_DISPLAY_MODE` to advertise a guest mode list (default 3840x2160). `Host::present_planes` sizes and resizes the host swapchain from the presented texture's actual dimensions. No independent runtime render-scale or upscaler setting is implemented in this checkout. The 1280x720 internal / 1920x1080 output target cannot be promised by changing these presets; it remains unimplemented/unverified, with no gameplay or visual run performed.

## 2026-11-27 - refreshed runtime preflight

- Re-ran the hardware collector at 05:57 CET and stored the full report outside Git. Available commit remains 9.74 GiB, below the 12 GiB launch floor; no runtime launch, shader prewarm, or gameplay run was attempted. The adapter and memory-budget values in the collector remain process-scoped and are not treated as the runtime's own DXGI budget.
- Re-ran `Test-AstraForgePreflight.ps1`: all 15 commit-gate cases passed. Re-ran `Test-AstraForgeBenchmarkHarness.ps1`: all six cache, cohort, frame-classification, comparison, and anonymous-export checks passed.
- No source or profile change was justified by this sample. O8 remains pending external install-path confirmation and a fresh passing commit preflight. Gameplay FPS, visual quality, and runtime stability remain unmeasured.

## 2026-11-27 - O8 memory follow-up

- Refreshed the external hardware report at 06:03 CET: 9.65 GiB available commit and 11.17 GiB available physical RAM. A read-only process scan found no single process above 1 GiB private memory. No process was stopped and no Windows memory setting was changed.
- The Xbox library root still has two executable candidates, while the runtime environment variables remain unset; neither candidate was selected or launched. O8 stays gated on confirming the authorized executable and passing the 12 GiB available-commit floor. No gameplay or performance result is available.

## 2026-11-27 - O8 pre-install checkpoint

- Refreshed the external hardware report at 10:08 CET: 9.71 GiB available commit and 9.92 GiB available physical RAM. This remains below the mandatory 12 GiB launch floor. The runtime directory and executable are still not configured; no process or Windows setting was changed.
- The installation is still pending per the user's update. Keep the full report outside Git; after installation, identify the correct executable without publishing its name or path, then re-run the adapter and commit preflight before any launch. No gameplay measurement has been made.

## 2026-11-27 - partial installation inspection

- The user supplied the external installation directory and asked for a read-only inspection while its download continues. The directory is present; a depth-limited metadata scan found one executable candidate. This is a partial-install observation only; the candidate is not confirmed as the runtime and was not launched. No file was changed.
- Refreshed hardware at 11:49 CET: 9.65 GiB available commit and 11.50 GiB available physical RAM. The 12 GiB commit gate still blocks a runtime launch. The unredacted path and complete hardware report remain outside Git.

## 2026-11-27 - runtime executable confirmed

- The user confirmed that the single executable candidate found in the external installation directory is the intended target. The launcher supports passing the directory and executable explicitly, so no private path needs to be saved in the repository or global environment.
- Refreshed hardware at 11:54 CET: 10.31 GiB available commit and 11.61 GiB available physical RAM. This is still below the mandatory 12 GiB launch floor. No runtime or shader prewarm was started; repeat the memory preflight immediately before the first launch.

## 2026-11-27 - installation preservation constraint

- The user explicitly requires all installed game files to remain untouched. The current metadata scans were read-only. Source inspection confirms the launcher rejects output, cache, or data paths inside the installation, and the benchmark harness rejects its output root there as well.
- Treat the installation as read-only for all future work. Do not patch, rename, move, overwrite, or delete its files, and do not change file attributes or permissions. Logs, captures, caches, and emulator data stay outside the installation and repository.

## 2026-11-27 - black-output capture and Claude Code handoff

- The latest diagnostic run completed its pre-run checklist and launched. The captured application window has a fully black render area. The user reports occasional logo flashes after manual controller input; automation did not inject input. The runtime has been stopped; the installation remains read-only.
- Audited the run directory outside Git. Runtime logs contain 29 warnings that a pipeline creation method is not implemented: 16 at slot `0x1c8` and 13 at `0x218`. The separate summary counter says zero draws dropped for missing host pipelines; that counter does not cancel the creation warnings. The last periodic engine summary reports 30.0 internal frames/s, 33.3 ms/frame, and 35 draws/frame, which is not classified application FPS.
- The same interval reports 695 textures uploaded (about 236 MB), seven waiting, 13 passed over unmapped, zero depth twins/plane draws, and no explicit device-removal or VRAM-exhaustion message. The screenshot, memory log, and full runtime logs remain outside Git. This identifies a graphics failure, not its root cause.
- `memory.csv` contains 50 samples: maximum process-private memory 6.85 GiB, maximum working set 4.03 GiB, minimum available physical memory 9.55 GiB, and minimum available commit 9.89 GiB. Process GPU counters peak near 1.73 GiB dedicated and 1.02 GiB shared. `nvidia-smi.csv` contains 333 continuous 1-second system-wide rows, with 1,138–2,960 MiB reported used and 2–100% utilization. These GPU totals cannot be attributed to AstraForge and the interval is not sustained gameplay.
- No `presentmon-frames.csv` was created. PresentMon stdout/stderr are empty; therefore it is unknown whether the user started the configured hotkey recording or attachment failed. The installed CLI help lists the configured process-ID, output-file, and hotkey options. Next, verify capture with a non-game smoke test before another scene run.
- Ported focused shader corrections from Vice-Tay merge `708dbfe` / PR #229 (Wave32 collision-register lowering, `v_add_f16` inline constants, root-constant table offsets), plus its NVIDIA static-sampler pipeline-library bypass from commit `fa8fc1d`. Focused shader tests, the pipeline-library bypass test (1/1), and host-pipeline tests (6/6) passed. A diagnostic artifact built as `20261127-142101-Diagnostic-thinlto-native-f14407dc`, SHA-256 `85F425828C5E34CBDDD1F0AD68FFC7DFCD18EEECCD6CBA30A94322C8F3F48503`, records `SourceDirty=true`. These patches are not yet confirmed to resolve the black output.
- Created `docs/CLAUDE_CODE_HANDOFF.md` and `docs/REFERENCE-REPOSITORIES.md`; refreshed the operational plan, fork comparison, launcher/benchmark notes, README status, source credits, and subtree local-change ledger. The requested COOL_FOX mirror cloned successfully outside Git at `f4b48ad766ddbec1a1867022cd42f7645b0dd55e`; seven other comparison clones are listed in the reference inventory.
- Model routing is documented as two optional, separate paths: OpenCode with DeepSeek Free Flash and a local Qwen coding model. `opencode` is not on PATH. The local model alias has not been checked. No API request was made and no key is stored in Git.
- Validation this turn: PowerShell parser check passed for the launcher, wrapper, and pre-run module; `Test-AstraForgePreflight.ps1` passed all 18 cases; `Test-AstraForgeBenchmarkHarness.ps1` passed all 6 cases; `git diff --check` passed; selected-document scan found no title/publisher or API-key pattern. These checks do not establish a rendering fix or gameplay performance.
- Next: trace the two warning slots from guest method handling through shader translation and D3D12 PSO creation, comparing only the matching graphics path in trustno PR #18. Preserve current uncommitted changes; do not repeat an unchanged black-screen launch. Do not commit or push until the user requests the reviewed change group.

## 2026-11-27 - PR #18 pipeline-piece correlation and lineage credits

- Reviewed trustno `VIctory-NVIDIA` PR #18 and fetched its head `e0703c136d472a67c5f00a1a9296d2e6790fcea6` into the external shallow reference clone. GitHub lists 58 commits / 64 changed files; a three-dot diff against the later local main snapshot lists 77 paths because the merge base is `9341f4316f0265786a95a6791a428f14d5695cb1`.
- The PR description states that methods `0x1c8` and `0x218` create pipelines from loose pieces; refusing those calls drops their draws, including a scene-composite path it associates with black/grey output. The latest AstraForge run logged refusals at both slots. This is a strong correlation and a leading hypothesis, not a confirmed root cause.
- The relevant donor commits are `cb33680`, `8823e15`, `0fae809`, `9449ec9`, `89bfaf0`, `c6a4b60`, and `c12a77f`. PR #18's compute-piece path still has reported wrong layouts; inspect a graphics-only path first. The local `VICTORY_RAW_COMPUTE` is a distinct, opt-in method-`0x218` path and does not implement the donor piece assembler. No donor code was imported in this review.
- Added the Vice-Tay lineage acknowledgements supplied by the user to `docs/source-credits.md`, explicitly distinguishing lineage credit from changes imported into AstraForge. The Cool_FOX public GitHub source resolves to the same `f4b48ad766dd...` commit cloned from the requested mirror; that mirror and all other repository references remain outside Git.
- Updated the Claude Code handoff and operational queue with the exact next investigation. No gameplay run, performance claim, commit, or push was made during this documentation/audit step.

## 2026-11-27 - O16 slot trace: PR #18 hypothesis downgraded

- Traced both slots locally. In `victory-gpu/src/device.rs`, table entries 57 (`0x1c8`) and 67 (`0x218`) call `unknown_pipeline::<SLOT>`, which nulls `out` and returns `E_NOTIMPL`. The opt-in `VICTORY_RAW_COMPUTE` affects only `0x218`. The current Vice-Tay shader and static-sampler patches do not touch this path. The warning logs only calls 1–4 and powers of two. In all ten logged local runs, the milestones reach at least 16,384 calls for `0x1c8` and 2,048 for `0x218`. In the latest run, every refusal happened between startup and about 1.5 s after it; none followed in the remaining ~5.5 minutes of black output.
- All seven forked reference snapshots carry the same refusal stub (COOL_FOX `f4b48ad`, trustno main `d12eb1b`, `victory-nvidia-8gb`, `VIctory-7900XTX`, `victory-fork`, `klbf-lab`, `victory-unified`). Base `VIctory` registers neither slot, so both calls reach its generic missing-method handler. The full PR #18 description measures an open-world baseline before its switch, while both slots are refused. It ties the black/grey world to pieces pipelines that were handed out and failed later. Its remedy refuses at creation, which matches local behavior, so the title falls back to its normal pipelines. PR #18's compute pieces still turn the world grey.
- Port assessment: the seven pieces commits change about 4,000 lines, including two new modules. Relative to donor base `67d9598`, the local `emit/lower.rs`, `emit/mod.rs`, `draw.rs`, `make.rs`, `device.rs`, and `pipeline.rs` each differ by 112–1,455 diff lines. Decision: no port for O16. PR #18 graphics pieces stay deferred as a performance/coverage candidate after a scene renders.
- Observed elsewhere in the same logs (all ten runs, before and after the current patches): 4–39 draws/frame, about 0 ms GPU time per frame, 0 draws dropped for missing host pipelines, about 2 ms process CPU per 33 ms frame, and storage-layer reads of world-data archives. The host view heap is capped at 1,000,000 views, and title slots at or above 737,855 read null. This is the documented NVIDIA layout ("highest seen slot about 720,000") and is not proven related. Hypothesis, not a diagnosis: the title stays in a front-end/loading state, and its few draws present black.
- Commands: `git grep`/`git show --stat` over the external reference clones; `gh pr view 18 -R trustno1-coder/VIctory-NVIDIA`; read-only `grep`/`sed` over the ten external run logs. No source, installed file, game launch, build, model API call, commit, or push was made. Docs updated: `docs/fork-comparison.md`, `docs/OPERATIONAL_PLAN.md`, `docs/CLAUDE_CODE_HANDOFF.md`, and this journal. `docs/source-credits.md` and the subtree `LOCAL-CHANGES.md` are unchanged because no source was imported.
- Next: from existing logs and source, trace what the early draws render and present, and whether the compose/present path writes the swap chain. Also determine what the title waits on after its world-data reads. Smoke-test PresentMon outside the game before any new launch.

## 2026-11-27 - black output root cause: revert `f8b6af5`

- With user authorization, diagnostic runs used `VICTORY_CAPTURE`, an existing diagnostics-build switch that saves presented frames as PNG. Captures, logs, and builds stay under `%LOCALAPPDATA%\AstraForge`. The installation was not modified.
- AstraForge diagnostic build `f14407dc`, Stability, 1920x1080 reported mode: every captured frame was a uniform black PNG, and the presents did reach the composer. Changing only `VICTORY_DISPLAY_MODE=3840x2160` gave the same result, and so did fresh cache and data directories.
- trustno PR #18 head `e0703c1`, built outside the repo with the same environment, rendered with `VICTORY_PIPELINE_PIECES=1` (graphics only): account screen, loading art, first-boot menus. A control run with the switch off rendered the same screens. That run later hit an access violation (null write) in title code at frame 2073, during story load; the title's crash uploader was blocked by the HLE network policy. The pieces hypothesis is therefore rejected for this symptom.
- Bisection over AstraForge source commits, with fresh cache/data and automatic stop at frame 600: import `a0748dc` renders; `f8b6af5` is black; `468b79b`, between them, changes test fixtures only. Cause: `f8b6af5` set the shader clamp to slot 737,855 but placed the 2^18 dynamic descriptors above it, so the clamp redirected every dynamic-table index to null.
- Fix: reverse-applied `f8b6af5` to `descriptor/host.rs` and `emit/shader.rs` in the working tree. Neither file had pre-existing uncommitted edits. The current tree, including all uncommitted Vice-Tay changes, renders the account screen and loading art in captures. `cargo test --locked -p victory-gpu --lib descriptor -- --test-threads=1`: 51 passed, 1 ignored. `cargo test --locked -p victory-shader --lib`: 283 passed, 4 ignored.
- Correction to earlier entries today: the claim that the run used single-plane presentation was wrong (a truncated `grep` hid the two-plane line). The O16 note that downgraded PR #18 still holds, now confirmed at runtime.
- User direction: stability first, test at 720p (`VICTORY_DISPLAY_MODE=1280x720`), no HD/4K targets yet. A user-driven 720p run of the fixed build was started. No FPS claim: the internal caption is not PresentMon data, and no PresentMon CSV exists yet.
- Next: commit the revert as a focused change; reproduce the story-load crash (O19) on the AstraForge build and trace it; smoke-test PresentMon.

## 2026-11-27 - story load reached; v0.1.0-preview prepared

- The story-load crash was the title's own watchdog (`+0x23cf683`, documented in `victory-fork` `memory.rs` as "GPU Loc Sig"). It fired after more than 30 s without a present. Fresh prewarm for the new translator fingerprint: seed SHA-256 `2ED14FEE...`; the shader cache then reported 915 hits and 0 misses. The remaining stall was driver pipeline creation: 94 slow static-sampler pipelines (201 s total, up to 7.8 s) that the NVIDIA library bypass rebuilt on every launch.
- With `VICTORY_LIBRARY_STATIC_SAMPLERS=1`, the library grew from 7 MB to 68 MB. The next launch loaded 1,145 pipelines, built 116, and entered the world with no exception. It sustained 2,500–3,800 draws/frame; all remaining dropped draws are the intentionally disabled ray-tracing passes. User-observed: heavy texture streaming lag, colours/materials largely missing, black characters, flickering, and lag even in settings menus. The internal caption read about 4–15 frames/s; that is not PresentMon data.
- Added `VICTORY_LIBRARY_STATIC_SAMPLERS=1` to the RTX 3070 baseline and documented its sampler-reuse risk. Made six focused commits. Clean portable build `20261127-161936-Both-thinlto-a53d1872` from `f528488`: `SourceDirty=false`, Release SHA-256 `CD39612F...`, diagnostic SHA-256 `062DAF2F...`. Checks: preflight 18/18, benchmark harness PASS, scripts parse with 0 errors, profile JSON valid, Release `--help` OK. The Release binary itself was not run in game.
- Next: diagnose the per-frame CPU cost visible even in menus; test `VICTORY_TEXTURE_NO_WAIT=0` for black characters and flickering; port the PR #18 sampler table; get PresentMon working.

## 2026-11-27 - v0.1.0-preview published; user-reported frame rates

- Published GitHub pre-release `v0.1.0-preview` (tag on `01a0928`; binaries from `bac1b76`, build `20261127-163329-Both-thinlto-3acbec4a`, `SourceDirty=false`, source paths remapped, built from a neutral worktree path; zip SHA-256 `111BC2A0...`).
- User-reported, **not validated**: about 7–9 average frames/s during story play and on a boat at sea. The source is the internal caption or overlay; no PresentMon CSV exists. A contributor (a relative of the user) tests on an RTX 3060 / 32 GB RAM PC and plans a pull request. Per `docs/GPU_PROFILE_SUBMISSION.md`, a 3060 needs its own `nvidia-rtx3060` identity from a DXGI query and a separate candidate tuning file. `nvidia-rtx3070` must not be reused or retuned.
- Next (unchanged): `VICTORY_THIN=0` A/B for CPU load (~95 ms/frame of list translation even in menus); `VICTORY_BAKE_TEXTURES_MS` A/B for black characters and missing colours; PresentMon smoke test.

## 2026-11-27 - RTX 3060 candidate profile and Vice-Tay observations (`host-02`)

- Added the candidate `nvidia-rtx3060` identity to `profiles/gpu-profiles.json`: device `0x2504`, 12,288 MiB, SM 6.6 minimum (6.8 observed), 32-lane waves, first-DXGI-adapter selection, nvidia-smi telemetry. `activeProfile` stays `nvidia-rtx3070`, and that entry is unchanged. Values come from `tools/Collect-AstraForgeHardware.ps1` on the target PC; the raw output stays in ignored `out/`.
- Added `profiles/rtx3060-profiles.json`, a separate tuning file whose values are copied unchanged from `rtx3070-profiles.json` (same source snapshot and Ampere family), with a `basis` note. Nothing is retuned for 12 GB without matched captures.
- Added `docs/RTX3060-hardware-report.md` (sanitized intake) and `docs/RTX3060-vice-tay-findings.md`: seven single gameplay runs on this GPU with the Vice-Tay tree, internal-report frame rates only (13.2 → 17.5 fps gameplay median; no PresentMon, not matched cohorts). Leads relevant here: the wave-wide form of two water compute programs draws black squares, so `VICTORY_WAVE_WIDE=1` should not be set globally; `VICTORY_WAVE_WIDE` is part of the translation-cache key; the CPU submission thread limits the frame rate; dropped indirect executions are the disabled ray-tracing passes.
- Added `docs/RTX3060-port-implementation.md`: how each of the 17 local Vice-Tay changes behind those runs is implemented, its origin, and whether AstraForge already has it. Port candidates: raw-view bounds (fxceless #1266), DXBC declared-size hashing (VIctory-NVIDIA #21), violet-probe discard (#29). No code from it is imported here.
- No AstraForge build, game launch, source change or benchmark was made for this entry. `docs/source-credits.md` and `LOCAL-CHANGES.md` are unchanged because no source was imported.
- Next: on `host-02`, run a `Start-AstraForge.ps1 -GpuProfile nvidia-rtx3060 -Profile Stability` preflight (enlarge the paging file first: available commit fell to about 1 GiB during emulation), then matched captures per `docs/benchmark-procedure.md`.

## 2026-11-27 - Vice-Tay #315 in game; PresentMon fixed

- Ported Vice-Tay #315 (`06f8dff`). Diagnostic build SHA-256 `043FF468...`. Fresh prewarm (seed `4F634033...`) seeded with the existing 147 MB pipeline library. A 720p Stability run entered the world with no exception, and the library loaded 2,704 pipelines and built 3. User-observed: NPCs still lack silhouettes, heavy flickering, wrong colours, about 12–15 frames/s (peak 15) from the caption. No regression observed; no visual fix claimed.
- PresentMon root cause: the launcher fell back to the NVIDIA FrameView SDK `PresentMon_x64.exe`. Run on its own, that copy exits with code 1 and no output, even for `--help`-valid arguments, with and without a unique `--session_name`; administrator rights were present. Installed official PresentMon 2.6.0 (Authenticode valid, Intel Corporation; SHA-256 `B2A706BC...`) under `%LOCALAPPDATA%\AstraForge\tools\presentmon\2.6.0`. A dwm.exe smoke test exited 0 with 231 rows, all `FrameType=Application`, and `--v2_metrics` as used by the harness is accepted. The launcher now prefers that folder over the FrameView copy (parse OK; preflight 18/18). No gameplay CSV has been captured yet.
- Next: first matched PresentMon gameplay capture (`scene-01`); A/Bs `VICTORY_THIN=0` and `VICTORY_BAKE_TEXTURES_MS`; port Vice-Tay #208 (paired wave64, water and character squares); review the RTX 3060 PR after its fix.

## 2026-11-27 - automated A/B session (user away; scripted input)

- Method: `Start-AstraForge3070.ps1`, Stability, 720p, the `06f8dff` diagnostic build, a warm cache, and `VICTORY_KEYS` (existing runtime switch) pressing Enter=A every 3 s until about 78 s. The world was reached automatically after 49–61 s. One variable per run, single runs, no 3-run cohort; scene timing varies because scripted A also skips cinematics.
- First PresentMon gameplay capture (baseline, 90 s, 864 `Application` frames): 9.81 average fps, 11.56 median, 2.35 1% low, 234 ms p95, `CPUBusy` 101.5 ms, `GPUBusy` 50.7 ms. Later captures lost 0.3–1.1 M ETW events and wrote no CSV; this is still unresolved. With PresentMon 2.6, `--v2_metrics` writes `FrameTime` instead of `MsBetweenPresents`, so `Measure-AstraForgeGameplay.ps1` needs a column fallback.
- Internal-counter means over about 2 minutes after the world appeared (not PresentMon): baseline 8.6 and 9.8 (clean rerun); `VICTORY_THIN=0` 11.3 and 8.7 (inconclusive); `VICTORY_TEXTURE_NO_WAIT=0` 10.3 (single run, black skin unchanged in captures); `VICTORY_CARD_BUFFERS=0` 1.8 (strong regression, so card copies are required). No profile default was changed.
- Cost breakdown in the world (baseline log): the submitting thread prepares 38–78 ms per frame, of which about 88–95 ms per frame (multi-run lines) is "copies in the card's memory"; translation threads report 34,000 list calls in 1.7–2.8 s of total thread time per frame. The indexed-texture pass costs 3–9 ms at steady state, with spikes of 45–53 ms. fxceless `VICTORY_HEAP_WORKER` would therefore address only the spikes here, so it was not ported.
- Visual: captures show the world rendering (vegetation, aircraft, fog) while character **skin** is black and eyes, lips, hair and clothes are correct. The local translator emits no fast-math flags, so the victory-fork fast-math cause does not apply. The leading lead is the skin-bake sources (victory-fork `VICTORY_BAKE_SOURCES`). `VICTORY_BAKE_TEXTURES_MS` is already on by default (1,500 ms); an earlier note that it was off was wrong.
- Regression found and fixed: force-stopped PresentMon left `AstraForge-<pid>` ETW sessions running. Five were found, plus a FrameView PresentMon process running since 12:50. All were stopped, and the launcher now stops its session (`7563028`). The next launch left no orphan session.
- Next: make PresentMon capture reliable (event loss); port the card-copy send-path optimizations (Vice-Tay #286, then #192); investigate skin-bake sources.

## 2026-11-27 (evening) — black skin is intermittent; fxceless bake-sources port

- Automated 720p runs (Stability, internal counters; PresentMon still loses 0.3–0.9 M ETW events and writes no CSV):
  - A, `0d66689` (#286): 9.4 fps, skin black.
  - B, `06f8dff` (#315 only): 10.6 fps, skin correct.
  - C, `0d66689` with Balanced (90 %): 5.2 fps, skin correct.
  - D, 94 % room plus `VICTORY_BAKE_TEXTURES_MS=5000`: 2.1 fps, 215 ms GPU per frame (VRAM overcommit).
- Findings from these runs:
  - Black skin is intermittent per run with identical settings, so it is not caused by #286.
  - More texture room is a large regression on 8 GB, so Stability (80 %) stays.
- Ported fxceless `b3d49db`, `082ebaf` and `2983a71` (`VICTORY_BAKE_SOURCES`, default on). GPU library tests pass (352 passed, 34 ignored). Six runs, three release and three diagnostic:
  - Each run brought about 180 stale skin-bake sources up to date, with 0 failures and no crash.
  - Internal fps was 10.1–11.9.
  - Skin was still black in one diagnostic run out of three. The port fixes a real stale-source case but is not the whole cause.
- Ruled out by log comparison between good and black runs: pipeline drops (identical, ray-tracing only) and all-zero texture reads (none).
- A render-target dump run (`VICTORY_DUMP_TARGETS=1` at two frames) was stopped by the host for low system memory before any dump was written. Retry with a single frame and more free RAM.
- Frame budget (all runs): about 55–70 ms preparing on the CPU, 30–36 ms copying back, and 7–13 ms on the GPU. 30 fps needs ≤33 ms in total, so the limit is CPU-side translation and readback, not the GPU.
- Next:
  - Dump G-buffer targets on a black-skin run to locate the stage (albedo versus skin lighting).
  - Consider fxceless #814 (`VICTORY_TEXTURE_DROP_MIPS`, lowers texture detail) only as an opt-in for 8 GB cards.

## 2026-11-27 (night) — v0.1.1-preview

- The release was built from `cbe2b36` in the neutral tree: build `20261127-212133-Both-thinlto-1b3c5bf9`, `SourceDirty=false`, paths remapped.
- Release SHA-256 `B3312F24…`; diagnostic SHA-256 `1593C2EB…`. A binary scan found no user path (only the neutral `\af\src`).
- Release-binary smoke test, one automated 720p Stability run: world reached at 82 s, 80 s in the world, no crash, 9.8 fps internal mean (5.5 minimum). PresentMon lost 0.54 M events and wrote no CSV.
- The README status table now describes v0.1.1-preview.
- Build note: `vcvars64.bat` could not find `vswhere` on PATH in this shell. Adding the MSVC `Hostx64\x64` folder to PATH was enough for `Build-AstraForge.ps1`.
- New upstream work to evaluate:
  - fxceless `2eade68c` (texture-block budget, which keeps the card under its VRAM line);
  - fxceless `cd935520` and `f299fba1` (32-lane water);
  - Vice-Tay `aa917f3f` (#343, shared heap-sync rounds) and `b9ef9252` (plan card steps once);
  - trustno `30b979ee` (arena storm, relevant only with the BVH builder).

## 2026-11-27 (night) — texture budget A/B, VRAM gate port, RTX 3060 PR merged

- `VICTORY_EARLY_TEXTURES_MS` A/B (diagnostic `v0.1.1` build, 720p Stability, one run each):

  | Setting | World reached | Internal fps | Uploaded at end | Waiting at end |
  |---|---|---|---|---|
  | 12 (default), run 1 | 79 s | 11.9 | 11,923 | 22,737 |
  | 12 (default), run 2 | 58 s | 11.9 | 14,110 | 18,610 |
  | 40 | 91 s | 10.0 | 13,949 | 24,538 |
  | 100 | 61 s | 10.9 | 12,801 | 17,891 |

  No clear effect. The queue plateaus at about 18–24k waiting textures in every run, so on 8 GB it is limited by room, not by pass time. The default was not changed.
- Ported fxceless `2eade68c` (texture-block gate, `39a187d`; adaptations are in `LOCAL-CHANGES.md`). GPU tests pass (356 passed, 34 ignored). One 4-minute session: VRAM held at 6.21–6.26 of 7.0 GB, with 9.9 fps internal and no crash. Earlier runs grew about 150 MB per minute.
- fxceless #814 `VICTORY_TEXTURE_DROP_MIPS` (focused port: CCS03 `847c925d`): started, then reverted. The local base already uploads from the first level a view shows (`VICTORY_HELD_LEVELS`, `level0`). The donor's level offset (`drop`) was written for a base without it, and combining the two needs a careful separate port.
- Merged PR #1 (candidate RTX 3060 profile, docs only) as `a441643`. The journal conflict was resolved by keeping both entries. The harness test passes.
- Race tracker: a second add request (#57) was closed without a stated reason, like #51. No further requests.
- BCPack: decoding runs on the CPU in the DirectStorage worker pool (`victory-hle/src/modules/dstorage.rs` via `victory-formats/src/bcpack.rs`), and detiling runs on the CPU in `victory-gpu/src/texture.rs`. Its share of CPU time is not yet measured: the per-thread CSV has no thread names. A GPU compute decoder is a multi-day option, to consider only after profiling shows it matters.
- Next:
  - A long session (≥ 15 min) to confirm the VRAM gate's long-session effect.
  - Profile the CPU per thread with names (ETW or `VICTORY_STACKS`) to size the BCPack/detile cost against list translation and readback.
  - A world "curtain" (keep presenting the loading picture until the queue settles), opt-in.

## 2026-11-27 (night) — CPU profile of world frames

- Method:
  - One automated 720p Stability run of the diagnostic build `39a187d` with `VICTORY_STACKS` every 2 s from 100 s to 176 s after launch, giving 39 samples in the world, about 100 threads each.
  - Frames were symbolized with `dbghelp` against the build's PDB (scratch script, not committed).
  - Stack sampling suspends threads, so that run measured 8.9 fps internal.
- Finding: the CPU is mostly idle. About 4 threads run at any sampled moment out of 16 logical CPUs; every other thread is waiting.
- Running samples per thread group (39 samples each):
  - title and driver threads: about 1.9 threads running on average;
  - list-translation threads: 14 running samples;
  - DirectStorage/BCPack workers: 13 running samples (about a third of one core);
  - late-wait helper: 12; submit thread: 10; relay: 9.
- Conclusion: BCPack decoding is not on the critical path for in-world frame rate. A GPU BCPack decoder would shorten loading but would not raise the in-world fps.
- Where the frame time goes:
  - The submit thread is usually inside `Host::submit` (called from `send_late`), waiting for GPU work to finish so its results can be copied back to title memory. This round trip, plus waits, accounts for most of the roughly 100 ms frame.
  - The late-wait helper spends its running samples resetting and recycling host lists, including driver allocation teardown (`NtGdiDdDDIDestroyAllocation2`, `FreeGpuVirtualAddress`).
- Next: evaluate the upstream work that targets submit-path synchronization:
  - Vice-Tay #343 (`aa917f3f`, share completed heap-sync rounds);
  - Vice-Tay `b9ef9252` (plan card steps once);
  - fxceless `VICTORY_DYNAMIC_WAIT` (lock stall fix).

## 2026-11-27 (late night) — where the CPU goes, scratch-pool fix, BCPack assessment

- Host buffer churn: a diagnostics-only count of upload and shared buffers by requesting source line was added (`note_made_at`). In about 100 s of play the largest sources were:
  - list scratch chunks: about 4,800 upload buffers;
  - list uploads: about 2,900 shared;
  - title-memory windows (`shadow.rs`): about 900 shared, 4 GB.
- Cause of the scratch churn: the sweep emptied the scratch pool every second under host memory pressure. Free physical memory stays near 1.3 GB, under the 3 GB mark, while the process holds about 17 GB.
- Fix `54e24f3`: keep the newest 64 MB (`VICTORY_SPARE_UNDER_PRESSURE_MB`, `0` restores the old behaviour).
  - Six interleaved runs of one binary: scratch creations −78 %, all host buffers about −30 %.
  - Internal fps unchanged (new 9.3/9.7/10.8, old 9.2/9.9/10.8). Churn was not the frame-rate limit.
- CPU by named thread, from the stack-dump thread names joined with `process-threads.csv` (run K):
  - Loading (208 CPU-s): D3D background threads 31 %, title and unnamed threads 29 %, our pipeline threads 25 %, DirectStorage/BCPack 7 %.
  - World (494 CPU-s): title and unnamed threads (including the driver's) 50 %, list translation 16 %, DirectStorage/BCPack 8 %, submit 6 %.
- Pipeline library: all 2,773 host pipelines were loaded from the library (`made=0`) within 29 s of launch. The driver's background CPU at start-up is that load, not recompilation. "World reached" in automated runs also includes menus crossed by scripted input every 3 s, so it is not pure loading time.
- BCPack assessment:
  - Decoding is 7–8 % of process CPU in both phases, and the decoded data must land in title memory, which our texture path then re-reads and uploads.
  - A GPU decoder (candidate: `POMXARK/bcpack-gpu-sdk`, MIT/Apache, 2 days old, self-reported benchmarks, prebuilt DXIL) would add a GPU→CPU→GPU round trip unless the texture path is redesigned to receive decoded blocks directly.
  - Not pursued now. If revisited: rebuild its HLSL from source, verify byte-exact output against `victory-formats::bcpack` on local streams, then measure loading time.
  - `Geolm/bc_packed` is a different format (its own BC re-compressor), not Xbox BCPack.
- Tests: `victory-gpu` lib 357 passed / 34 ignored, and with diagnostics 416 / 35.
- Next: the frame is serialized on the single submit thread (82–147 ms worked per frame, title threads waiting 50–87 ms at presents). It needs a submit-path trace with timestamps per phase (heap sync, card steps, copy-back) rather than more stack samples.
- Bus traffic leads (run M-new-3, one 5-second world line, 7.8 fps):
  - Host copies move 38.4 MB up and 39.3 MB fetched per frame. One 20 MB title buffer alone moves 21.05 MB up and 21.04 MB back every frame, in 321 pieces that go both ways: both the title and shaders write it. That buffer is half of all bus traffic.
  - What shaders wrote, put into title memory: 142.2 MB per frame in 3,890 pieces (`VICTORY_EXACT_BACK`).
  - Write-tracker guard-lock waits: 17.55 ms per frame across threads.
  - The ping-pong buffer is the next concrete target: find which title resource it is and whether its CPU and GPU halves can be kept apart, or its round trip skipped when the title does not read it.

## 2026-11-28 (night) — memory pressure, rejected experiments, and the title's hang watchdog

Method change: one change at a time, judged by log counters (VRAM in use, textures waiting, card-copy refusals, free RAM, crashes) and a fixed visual check in the opening scene, not by impressions alone. Nothing below was committed except this record.

- Vice-Tay #321 (write watch for large `XMemAllocDefault` allocations, both switches on): rejected. It does find the 20 MB buffer that is copied whole about twice a frame, but on this PC the shader results landing in it re-dirty its pages. Watched pages per frame rose from about 2,500 to 7,800, and copy-back took 45–115 ms. Internal fps before the profiler window was 3.8 with it, 11.4 without (same binary, two runs).
- `VICTORY_PROFILE` sampling (28 threads every 25 ms): both runs crashed about 40 s into the sampling window, with the same stack in the C runtime. It is not used for timed or played runs. `VICTORY_STACKS` snapshots did not crash in earlier sessions.
- Texture-block gate off with the sweep back at 88 %: rejected. In the user's play VRAM reached 6.86 of 7.07 GB (97 %), title buffers were refused card copies 40 times, and over 1,000 textures waited. Characters and an animal in the opening scene were black.
- Dropped work per frame in the world: about 430 indirect dispatches that shade ray-tracing hits and about 85 stages of the BVH builder. Both are dropped because the builder is off (`VICTORY_BVH_BUILDER`, upstream status: not working end to end). This is not a separate indirect-translation bug.
- System-memory texture tier (textures the card has no room for placed in an L0 custom heap, up to 1 GB): rejected and kept as a local patch only.
  - The texture queue stops at the card's line before the pool, so the tier first never engaged.
  - Opening the queue also let card blocks and tiled levels grow: VRAM reached 8.4 GB of a 7.1 GB budget, internal fps fell to 0.6, and the system pagefile grew to 34 GB.
  - Restricting new textures to free card pieces or system memory still left VRAM at its budget and free RAM at 1.1 GB, and the run ended in a crash.
  - Conclusion: on this PC both VRAM and RAM are under pressure. Moving data between them does not help; reducing duplicate copies does.
- Disk: the build helper keeps a full `cargo-target` per build. About 30 GB had accumulated under `%LOCALAPPDATA%\AstraForge\builds\artifacts` and filled drive C: together with the pagefile. Old artifacts were deleted; prune them after builds.
- Crash analysis (six crashes on 2026-11-27):
  - Four stopped at the same title address. Disassembly of the local title image shows a deliberate write to address 0 with an error code, reached from the title's hang watchdog.
  - The watchdog runs once a second and keeps a 64-entry, per-thread table of open "watched scope" timestamps. It stops the title when a scope has been open for more than 300 s. In every case the crash came about 300 s after process start, so a title thread entered a watched scope early and never left it.
  - None of the six crashes followed a refused Windows commit. Three happened with 6–9 GB of RAM free. They are not host out-of-memory crashes.
  - The other two (C runtime, read of address 0) happened only in the `VICTORY_PROFILE` runs.
- Window copies outside buffers: 2,676 MB alive in a diagnostic run, of which only 1,448 MB lies between the lowest and highest address ever asked for in each window. `VICTORY_WINDOW_KB` (finer grid) and `VICTORY_WINDOW_TAILS=1` exist upstream but have never been measured here.
- Repository: history rewritten to remove a third-party service reference from documentation; `main` and both tags were force-pushed. Clones must reset to `origin/main`.
- Next:
  1. Hardening: identify the title thread stuck in a watched scope with `VICTORY_STACKS` snapshots near 280–290 s, then find the wait our layer never completes.
  2. Memory: measure the window grid and tails switches by window bytes, free RAM, VRAM and internal fps.

## 2026-11-28 (night, later) — window grid in the RTX 3070 profile, and what the title's watchdog really checks

- Window copies outside buffers on a 1 MiB grid with tails (`VICTORY_WINDOW_KB=1024`, `VICTORY_WINDOW_TAILS=1`), three interleaved pairs of automated 720p runs on one diagnostic binary:
  - Host copies of title memory alive: 2,777 and 2,725 MB, against 3,306, 3,258 and 3,390 MB on the 4 MiB grid.
  - Window copies: 1,967 MB against 2,492 MB (first pair).
  - Frame preparation: 89 and 111 ms against 116, 139 and 240 ms. Copy-back: 42 and 47 ms against 62, 68 and 71 ms.
  - Internal fps unchanged (6.2 and 5.8 against 6.2, 6.0 and 4.5).
  - One run of the three on the finer grid stopped during loading from the title's watchdog (below). The same stop happened four times on the 4 MiB grid on 2026-11-27, so it is not attributed to the grid.
  - Adopted in `profiles/rtx3070-profiles.json` (`baselineEnvironment`). The RTX 3060 candidate profile is unchanged.
- The watchdog's table was saved at that stop (`VICTORY_CRASH_SAVE`). No thread had an open watched scope: every count was 0.
  - The stop came from the watchdog's second check. When no scope is open, it compares a global progress timestamp, written by the title's update loops at the start of each pass, with the value it saw last.
  - After 30 one-second checks without a change, it stops the title.
  - So the title's update loop did not run for about 30 s. In the log, that window was in loading, with no frames and with thousands of waits for new card memory to become resident.
- Added `VICTORY_CRASH_STACKS=1` (diagnostics builds): a reported crash prints every thread's stack, which shows where the update loop is stuck at the moment the watchdog fires.
- Tests: `victory-loader` lib 40 passed, 43 with diagnostics. Release and diagnostic builds succeed. The benchmark harness synthetic suite passes.
- Next: run with `VICTORY_CRASH_STACKS=1` until the watchdog fires again, then fix the 30-second stall it shows.

## 2026-11-28 (night) — the stall behind the watchdog stop

- Caught with `VICTORY_CRASH_STACKS=1` (run HANG-2, during loading). The stop is the title watchdog's progress check (no update-loop pass for 30 checks of about a second), not a crash in our code.
- The title's update-loop thread was in the frame-pacing wait under its update function: the function enqueues a frame, and while two frames are in flight it spins (`monitorx`/`mwaitx` with `SleepEx`) until a frame completes. The title's main thread was in its usual long wait and is not involved.
- At that moment three of our list-recording threads (`victory-list-2`, `-5`, `-7`) were inside `ID3D12Device::MakeResident`, called by `host::resident` for new committed textures and render targets (`resource::host_texture_as`, from `make_twinned` and `set_targets`). The other recording threads waited on them.
  - The run's log counted 34.4 s spent in `resident` over 7,000 calls, the longest 683 ms.
  - With the card near its budget, a synchronous `MakeResident` waits for the system to page other memory out. No frame completed, the title stayed two frames ahead, and its watchdog stopped it.
- `VICTORY_WAIT_RESIDENT` (on by default) creates such memory non-resident and waits for it, because reading memory that is not yet mapped lost the device in earlier upstream runs. Turning it off is not a fix.
- RAZDA4A-XEN (`dev`) only splits off plain buffers from this wait (`resident_buffer`). Textures and targets still wait.
- Candidate fixes, to be measured:
  1. `EnqueueMakeResident` with a fence that the queue waits on, so the CPU does not block.
  2. Keep new committed textures and targets within the budget during loading, so that residency does not page.

## 2026-11-28 (night) — write-combined copy-back port; window grid taken back out of the profile

- Ported VIctory-NVIDIA `50c15a14` and `2f81d0c8` (`VICTORY_WC_NO_BACK`, `VICTORY_WC_NO_BACK_MIN_KB`).
  - With no minimum, the user saw wrong faces in play: small results the title reads back stayed on the card. This matches the donor's own note about stale exposure.
  - With a 64 KiB minimum, three interleaved run pairs gave copy-back of 21.5, 20.2 and 21.2 MB a frame, against 33.5 MB in the one comparison run that reached the world. Copy-back time, frame time and fps stayed within run-to-run noise. The user saw no new defect.
  - Adopted in the RTX 3070 profile at 64 KiB.
- Window grid (1 MiB with tails) taken back out of the RTX 3070 profile.
  - Runs with it stopped during loading from the title's watchdog in 4 of 12 cases, against 0 of 3 on the 4 MiB grid that night.
  - Finer windows mean many more window buffers made while loading. More new memory means more synchronous `MakeResident` waits, which is the stall found above.
  - The evidence is thin, and the memory saving stays documented. To be re-enabled once residency no longer blocks.
- Intermittent black face reproduced in two runs at the same scene (about world frame 1300). In another run the same face was correct, so it is timing-dependent and not caused by the write-combined port.
- No release this night: the loading stalls stop too many runs to publish a binary for everyone.

## 2026-11-28 (night, late) — black albedo, the render-target reserve, and one combined test

- Captured the black face (`VICTORY_DUMP_TARGETS` at world frame 1296).
  - The G-buffer's albedo target already has the face, the hands and the room's walls black, while the lips, glasses, hair and the other character are right. So the black comes from missing textures, not from light.
  - At that frame about 21,000 textures picked by index were waiting. The queue had refused 488 passes for lack of room with the card at 5,742 of 6,852 MB.
  - In another run the same face was right: the outcome depends on timing.
- Cause of the refusals: the texture queue keeps `VICTORY_CARD_ROOM_FOR_TARGETS_MB` (3,072) less the render targets made. At 720p, targets hold about 1.2 GB, so about 1.9 GB stays kept for the whole run.
- Ported from VIctory-NVIDIA in one batch:
  - `6726920a`: BC7 rotation in BCPack.
  - `89fd9361`: view table cap.
  - `30b979ee`: arena retries.
  - `aec85efb`: raw view clamp.
  - `826ba150`: violet probe filter.
  - `21b040da`: the reserve is given up once targets settle; it does not fire at 720p with the default 3,072 MB.
  - Not taken: lane tickets and dynamic slot identity (conflicts), and early depth (it would invalidate the shader cache for a switch that is off).
- One combined test with the reserve at 1,536 MB in the RTX 3070 profile, so that it settles at 720p: rejected.
  - Internal fps fell to 0.1–1.6.
  - Synchronous residency waits reached 108–308 s per run, with single calls up to 3 s.
  - Two of five runs stopped before the world.
  - With the textures given that room, the card goes over budget and every new allocation pages.
  - On an 8 GB card the reserve works as headroom against paging. The override was removed.
- Control with the ports and the default reserve:
  - The diagnostic run was in line with earlier runs: 5.95 fps, preparation 140 ms, copy-back 56 ms.
  - The Release run was stopped by the title watchdog during loading while frames still came at 30 fps. That stall predates these ports.
- Lesson: on 8 GB, black textures and residency stalls share one cause, too little card memory. Next:
  1. Make residency non-blocking.
  2. Shrink our own card and host copies.
  3. Only then give textures more room.
- No release: loading stops by the title watchdog still end too many runs.

## 2026-11-28 (night, last) — textures into free block pieces; in-place windows held back

- The control run's room line read: 6,064 MB in use, less 1,100 MB free in texture blocks, plus 96 MB kept for buffer copies and 1,721 MB kept for render targets, giving 6,781 MB against a 5,525 MB line. So the queue had no room while 1.1 GB of card memory we already hold lay free in the blocks.
- New `VICTORY_TEXTURE_PIECES` (on by default). With the room test saying no, the pass goes on for textures that fit a free piece of an existing block. No new block, no level tiles and no dedicated allocation, so no new card memory and no residency call.
- Runs with the same diagnostic binary:
  - On: textures waiting about 6,300 on average, against about 24,200 off. Free block room was 70 MB on and 1,227 MB off.
  - Residency waits were low with it on (2.3 s per run).
  - Of the two runs with it on, one reached the world without a stop; the other was stopped by the title watchdog during loading. The off runs had the same stop elsewhere this night, so it is not attributed.
- `VICTORY_INPLACE=1` (in-place windows, existing upstream switch), one run: 75 windows (364 MB) were read in place, and private memory was 15.4 GB against 16.7 GB. The run stopped during loading with all seven recording threads waiting on a lock inside the NVIDIA user-mode driver while binding. Held back until that is understood.
- Tooling note: force-stopped runs leave `AstraForge-*` ETW sessions running, and the next launch then fails before the runtime starts. Stop them with `logman stop <name> -ets`.
- Still open: the title watchdog stops part of the runs during loading. Black textures are much reduced in the counters but not gone, and the user has not yet reviewed them in play.

## 2026-11-28 (early morning) — free pieces turned off, watchdog patience, memory types

- `VICTORY_TEXTURE_PIECES` isolation, same diagnostic binary and watchdog patience, one run each:
  - Off: the world reached at 79 s; 3.8 fps; preparation 220 ms; residency waits 17.7 s in all, longest 0.4 s.
  - On: the world reached at 128 s; 0.03 fps; preparation 10.8 s per frame; residency waits 85 s, longest 4 s.
  - The earlier good run with it on was luck. Filled pieces keep blocks resident that the system could page otherwise, and the card pages instead. Now off by default; it was on in `0b003a6`.
- Title watchdog patience (`VICTORY_WATCHDOG_SECONDS`).
  - The function is found by signature, and 8 of 8 places are patched, as the run log says.
  - Before it, the four memory-type runs stopped during loading, both with the switch on and with it off.
  - With 120 s, both isolation runs reached the world, one of them at 0.03 fps. Set to 120 in the RTX 3070 profile.
  - A real hang is still stopped, after about two minutes.
- `XMemAllocDefault` memory types.
  - The allocation attributes carry a memory type, and several types are CPU write-combined.
  - The title asks for blocks of 1 MiB or more of the graphics write-combined type: 82 MB, 16 MB, 8 MB.
  - Noting them as write-combined (`VICTORY_WC_XMEMALLOC=1`) was followed by stops during loading in both runs with it on. With patience not yet in place, that cannot be told apart from the general stops. It stays off until measured with patience.
- VRAM in a diagnostic run, about 6,065 MB of a 6,906 MB budget:
  - texture blocks about 2,880 MB, of which 1,100 MB were free pieces or spare empty blocks;
  - render targets 1,349 MB, including two 3840x2160 targets at 720p output;
  - card copies of title buffers 1,007 MB;
  - about 830 MB other.
- Next: spare empty texture blocks on 8 GB cards; why 4K targets are made at 720p; a lower cap for card copies of title buffers. Each to be measured with watchdog patience on.

## 2026-11-28 (late morning) — card-copy caps, console API behaviour, VRAM targets

- Card-copy cap (`VICTORY_CARD_BUFFERS_MB`), diagnostic binary with watchdog patience, one run each:
  - 2,048 MB (current default for 8 GB): 4.1 fps, preparation 224 ms, copy-back 97 ms.
  - 1,024 MB: 1.3 fps, 552 ms and 169 ms, because more buffers are read over the bus.
  - 512 MB: the launch produced no runtime log.
  - The default is kept.
- Console API behaviour checked against the runtime:
  - Extended indirect argument type 105 is the single-pass dispatch. Its only field is dispatch flags, and the title passes 0. The current handling matches.
  - The queue's method order matches our table for every method we implement. Some console-only queue methods are absent (the explicit-flush signal and the extended wait among them). No calls to them were logged.
  - Device methods `0x1c8` and `0x218`, documented upstream as unknown, are the graphics and compute pipeline deserialization calls.
    - Their description layout confirms what upstream had inferred for compute.
    - The title falls back to creating pipelines from containers when they fail: about 16,000 graphics deserialization failures in a run, while 2,783 pipelines were made and 2,726 bound.
    - Only ray-tracing draws were dropped for a missing pipeline. These failures are not a cause of missing objects.
  - Console GPU caches are not coherent with the CPU. GPU writes to non-coherent memory become visible to the CPU only after an L2 writeback that the title asks for: barriers, explicit pipeline flushes, or signals with flush flags. This is the basis for copying shader writes back only when the title asks, a larger change not yet started.
- VRAM: the texture blocks hold 1.1–1.3 GB of free room that new textures do not always fit. These are pieces left by released textures, not spare empty blocks, which are already cut to 2 above 85 % of the budget. The texture line now logs block fullness, to decide on compaction.
- Next, with the user's go-ahead for runs: measure a Release build of current `main` as the reference for the fps goal; read block fullness from one diagnostic run.

## 2026-11-28 (midday) — cache-sync behaviour, sample mask, BCPack BC7 mismatch

- Method tables checked against the console API: every queue, device and command-list method we implement sits at the right slot.
  - List method `0x470`, marked unknown upstream, is the per-quad sample mask. It is logged now, not applied.
  - List methods `0x418`/`0x420` are the top- and bottom-of-pipe syncs.
- The title's pipeline syncs fall into two kinds:
  - partial flushes that only wait for shaders to finish (`0x100000`, `0x700000`);
  - full syncs that also write the shader level-2 cache back to memory and invalidate caches (`0xc280`, `0xc380`, `0xc3c0`).
  - On the console, shader writes to non-coherent memory are visible to the CPU only after such a write-back. Copying shader results back only after a write-back could cut the copy-back, which costs 60–100 ms a frame. The size of the gain depends on how many submissions end without one.
  - New counters log both kinds, for list syncs and for fence signals with sync settings. Signal settings were ignored before.
- BCPack: our decoder was compared locally against a reference implementation kept outside the repository, on synthetic block streams.
  - BC1, BC3, BC4 and BC5: byte-exact in 22 of 22 cases.
  - BC7: every compared block differs in its index bits, while the endpoints match, in both random and repeated-block streams.
  - Synthetic random blocks may reach paths a real encoder never produces, so this must be confirmed on real texture streams before changing the decoder. It is a candidate cause of wrong texture detail.
  - BC2 is not supported by our decoder. Whether the title uses it is not known.
- Graphics pipeline deserialization failures (about 16,000 a run) are harmless: the title creates the same pipelines from containers.
- `VICTORY_WC_BAR` (one card copy of write-combined title buffers, mapped by the CPU) is possible here: this RTX 3070 has a full-size BAR (8 GiB). The copy is made only while a fifth of the card budget is free, which an 8 GB card rarely has.
- Next, all to be implemented before one test session, as the user asked:
  1. Find the BC7 index difference in `victory-formats/src/bcpack.rs`, with a unit test.
  2. Gate shader-write copy-back on level-2 write-backs (behind a switch).
  3. Let `VICTORY_WC_BAR` work under a lower free-budget line on 8 GB cards.
  4. Then one session: Release reference, sync counters, block fullness, the switches on and off.

## 2026-11-28 (afternoon) — BCPack BC7 decoder fix

- Found with byte-exact comparisons against reference outputs made outside the repository: one-block-type streams for every BC7 mode, with all-zero, all-one and random indices.
  - All-zero indices decoded right in every mode.
  - Non-zero indices decoded wrong whenever the block's index reference pointed into the BC7 dictionary, and right with no reference.
- Cause: each BC7 dictionary entry holds 16 + 16 index words right after its two width bytes. The table parser skipped one word, taking it for a repeat of the widths, and read 31. Every dictionary entry's indices were therefore one pixel off.
- Fix in `victory-formats/src/bcpack.rs`. The dictionary test now checks the layout, with a regression value for entry 231.
- After the fix, everything is byte-exact against the references:
  - BC7: 53 streams, every mode, random, repeated and mixed blocks;
  - BC6H: 28 streams, every valid mode;
  - BC1, BC3, BC4, BC5: 22 streams.
  - `victory-formats` lib: 42 passed. DirectStorage tests in `victory-hle`: 19 passed.
- Expected effect in play, not yet observed: BCPack BC7 textures, the common high-quality colour format, show correct pixel detail where dictionary references occur. Before, such blocks had wrong indices, which looks like noisy or wrong-coloured detail.
- BC2 remains unsupported. Whether the title uses BC2 is not known.
