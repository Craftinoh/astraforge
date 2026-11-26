# AstraForge — progress journal

This file is the durable task record. Update it when source, build, benchmark, hardware, publication, or user plans change.

## Current objective

Prepare AstraForge as a profile-driven Xbox compatibility layer. Start with NVIDIA RTX 3070 Ampere, target at least 30 real gameplay FPS with a 1% low of at least 30, and add AMD only in a later separately validated phase. Keep public benchmark reporting anonymous and do not identify the game title.

## Workspace and source

- Workspace: `workspace root`.
- Main workspace is now a Git repository on branch `main`, with the public GitHub remote `Craftinoh/astraforge`.
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

These source changes have not yet passed a local Rust build or Windows GPU test because the pinned Rust/MSVC/DXC toolchain is unavailable.

## Workspace tooling and evidence

- Hardware probe and current host report: `tools\Collect-AstraForgeHardware.ps1`, `out\hardware-latest.json`.
- Four RTX tuning candidates: Stability, Balanced, Performance, Quality. They differ by `VICTORY_TEXTURE_ROOM_PERCENT` and have not been measured locally.
- Build helper: `tools\Build-AstraForge.ps1`; it now creates a unique external Cargo target/artifact directory and records hashes. Thin LTO + native CPU is the Ryzen 7 7700X candidate build.
- Runtime launch: `tools\Start-AstraForge.ps1` reads `profiles\gpu-profiles.json`; the RTX 3070 wrapper remains available as `tools\Start-AstraForge3070.ps1`. The profile-file path bug is fixed, and adapter, D3D12, wave-width, compute-capability, dedicated-memory, and commit checks are manifest-driven.
- Shader prewarm: `tools\Prewarm-AstraForge.ps1`; it accepts an isolated cache seed and writes a fingerprint manifest.
- Gameplay capture: `tools\Measure-AstraForgeGameplay.ps1`; comparison: `tools\Compare-AstraForgeRuns.ps1`; cache functions: `tools\AstraForge-BenchmarkCommon.psm1`.
- Synthetic test command: `tools\Test-AstraForgeBenchmarkHarness.ps1`. The latest run passed cache seed cloning/mutation detection, three-run cold/warm comparisons, target evaluation, anonymous report export without local paths, and rejection of mismatched warm seeds and unclassified frames. All ten PowerShell scripts/modules parsed successfully after the GPU-profile refactor.
- Release, diagnostic build, actual shader prewarm, and gameplay captures have not succeeded or been run. No local FPS result exists.

## Performance evidence and target risk

The closest 8 GB NVIDIA source report measured about 17 FPS (58.2–59.4 ms/frame) on a different RTX 3070 Ti system. Its submitting CPU thread measured 55.9 ms while the GPU was about 64% busy, with roughly 21 ms idle behind submission. That points to a CPU-side submission bottleneck on that host. This system's Ryzen 7 7700X differs, so the result is not a prediction. Thin LTO, native CPU code generation, and PSO prewarming are candidates; each requires an A/B gameplay capture. The 30 FPS goal remains unverified.

## Current blockers and user update

- User is installing the Xbox game on this PC. After installation, inspect only for a locally usable VIctory-compatible executable and keep all personal game data outside the repository. Current `VICTORY_GAME_DIR` is unset.
- `cargo`, `rustc`, `rustfmt`, MSVC `cl/link`, DXC, and PresentMon are not currently available through the shell. Git 2.56.1 and GitHub CLI 2.106.0 are installed and GitHub authentication is valid.
- The public repository `Craftinoh/astraforge` has been created. The local history includes the source subtree and all local patch commits; the first push is the next publication step.

## Publication and privacy rules

- Do not name the game title in public project documentation or benchmark reports.
- Public route labels must be neutral, e.g. `scene-01`; omit executable names, title identifiers, save IDs, user paths, raw logs, and account names.
- Keep game files, caches, saves, raw hardware reports, and generated executables outside version control.
- Retain all original source notices, GPL-3.0 license terms, and upstream commit/PR credits.
- The intended project direction is NVIDIA-first with data-driven GPU profiles; do not add AMD tuning until its adapter selection and validation are implemented.

## Next actions

1. Push the reviewed `main` history to the public repository and verify that no ignored local artifacts were published.
2. Install/enable the pinned Rust, MSVC, DXC, and measurement toolchain, then build Release/diagnostic variants and validate the launch path.
3. Collect repeated warm/cold gameplay cohorts, verify resolution, review rendering, and report measured memory and frame-time behavior.
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
- Created the public GitHub repository `Craftinoh/astraforge`. Publication verification remains pending until the first push completes.
