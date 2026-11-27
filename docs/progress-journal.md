# AstraForge — progress journal

This file is the durable task record. Update it when source, build, benchmark, hardware, publication, or user plans change.

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

## Verified host snapshot

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
