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
