# Change log

## 2026-11-27 - per-heap texture bake coverage

- Replaced the global completion counter for decoration texture bakes with per-heap queue revisions. Overlapping passes, queue writes during a scan, incomplete capped snapshots, or budget-limited scans cannot certify coverage. The synchronous path records coverage after GPU execution and descriptor publication.
- Adapted the focused fix from Vice-Tay #85 and added regression coverage for heap isolation, stale revisions, overlapping passes, and truncated snapshots.
- The diagnostic GPU-library suite passes serially (407 passed, 35 ignored); optimized Release passes serially (349 passed, 34 ignored). A parallel run showed an intermittent existing test/process failure, recorded in the progress journal. No gameplay, visual, stability, or FPS effect is measured.
- Clean Release and diagnostic executables built at `20261127-050134-Both-thinlto-native-a19ebb64`; both `--help` checks pass. SHA-256 hashes are recorded in `docs/progress-journal.md`; binaries remain outside Git.

## 2026-11-27 - shadow comparison boundary correctness

- Fixed the first worker's aligned cut in `Shadow::differing`: saturating subtraction keeps a comparison range that starts inside a 64 KiB title-memory piece from wrapping before its start. The previous code panicked with overflow checks and could skip the first slice in Release.
- Ported the focused correction from Vice-Tay #114, adapted from fxceless #1407, with original finding credit to Kelvaroq's `stellarr-studio/kelvaroq` patch 0009. Added a synthetic 48 MiB regression that reproduced the failure before the fix.
- The regression passes in debug and Release. This is a correctness result for the tested partitioning path; no gameplay, visual, stability, or FPS result is implied.

## 2026-11-27 — hard commit-headroom preflight

- Added a shared PowerShell check for the launcher and gameplay measurement entry point. The default floor is 12 GiB; callers may raise it but cannot lower it. Removed `-AllowLowCommit`, and invalid, negative, NaN, and infinite samples fail closed.
- Moved warm cache seed copying until after hardware and commit preflight, so a rejected low-memory run does not first make a large cache copy.
- Added `tools/Test-AstraForgePreflight.ps1`. Its 15 passing cases cover accepted/rejected thresholds, each entry point's rejection of a below-floor value and the removed bypass parameter, and the gate-before-cache-copy order.
- This guard reduces the chance of starting while Windows reports low commit headroom; it does not predict the application's future allocations or establish runtime stability. The current host sample remains below the floor.

## 2026-11-27 — Ampere descriptor safety and local builds

- Added opt-in `VICTORY_FILL_TITLE=2`, a stricter condition for bypassing small in-flight memory waits. Mode `1` behavior and the unset default are unchanged; no supplied profile enables mode `2`. The change is ported from Vice-Tay commit `b6be7e3`, with three predicate tests. Clean Release and diagnostic builds completed at `20261127-033517-Both-thinlto-native-5aaf5812`; gameplay correctness and performance remain unverified.
- Canonicalized padding and dimension-unused words in placed SRV/UAV descriptions before shape keying. This focused Vice-Tay #27 port prevents logically identical placed views from consuming millions of false shapes because of unwritten bytes. Added resource-padding and unused-union regression tests; all ten descriptor tests pass. Gameplay memory and rendering remain unverified.
- On the 1,000,000-view portable D3D12 heap, moved the shader clamp's null slot ahead of the fixed 2^18 dynamic descriptor tail. Title-visible descriptors are limited to the range before that sentinel, preventing an out-of-range title index from reading a live per-draw descriptor. Added a regression test for the disjoint ranges.
- Initialized cached system commit headroom to zero until Windows returns a valid `GlobalMemoryStatusEx` sample. A failed initial sample now pauses speculative texture/staging admission rather than treating the memory budget as unlimited.
- Corrected two indirect-budget test fixtures after GPU execution showed their expected values contradicted the all-or-nothing budget semantics. The indirect shader behavior itself is unchanged.
- Built clean-source Release and diagnostic executables using the pinned Rust 1.98.1 MSVC toolchain, Rust Thin LTO, one release codegen unit, and native CPU code generation. Build ID, source commit, artifact sizes, and SHA-256 hashes are recorded in the progress journal.
- The `victory-gpu` library suite passed 340 tests; 34 were ignored. The full workspace suite passed 934 tests; 47 were ignored and 0 failed. Both binaries returned success for `--help`. No gameplay launch, visual review, shader prewarm, or FPS capture has occurred; no performance gain is claimed.

## 2026-11-26 — RTX 3070 runtime scaffolding

- Added four launcher profiles tied to the audited `grimygunnz/nvidia-3070-VI` source snapshot. They differ only in the verified dynamic `VICTORY_TEXTURE_ROOM_PERCENT` control (80/85/90/95); all are marked as unbenchmarked on this PC.
- Added a launcher that verifies the profile's source semantics, requires Series S by default, checks the default DXGI adapter and commit headroom, and records logs and memory counters outside the repo/game directory.
- Extended hardware detection with `nvidia-smi` BAR1 mapping data; the latest 8 GiB aperture matches the framebuffer and indicates Resizable BAR is likely enabled. The report labels this as an inference and keeps BAR1 counters separate from VRAM residency.
- Refreshed the live hardware report at 21:44 CET: RTX 3070 is still the first DXGI adapter and available commit is 14.95 GiB (above the 12 GiB local preflight, below the separate ~20 GiB community footprint).
- Imported the complete GPL-3.0 NVIDIA 3070 source snapshot at `6e9c1dd` with a blob-hash manifest. Kept the upstream source as a nested repository with separate local import and patch commits.
- Fixed the Clippy precedence error in `victory-formats/src/texture.rs` reported by current upstream CI. The behavior is unchanged; at the 2026-11-26 entry date, local Clippy/build verification was pending because the Rust toolchain had not yet been installed.
- Synchronized upstream `docs/nvidia-8gb.md` at `25ff216`; documented the rejected refresh-ahead experiment and crash evidence. No runtime source was imported by this docs-only update.
- Ported the open fxceless #1044 DirectStorage worker-count change as a separate source commit: use detected physical cores instead of all logical threads, with a bounded override for A/B runs. Its upstream copy-back measurement is recorded; the local build and FPS effect remain unverified.
- Ported merged fxceless #1324 as a separate descriptor correctness change: dynamic slot ranges now carry host-heap identity, preventing stale list resets from freeing ranges on an address-reused heap. Added its wrong-identity regression test; local execution is pending.
- Ported `victory-unified@768735a` as a separate descriptor lifetime fix: descriptor nulling and resource release wait until GPU submissions are idle; added a guard against overwriting texture views while submissions are flying and a remade-slot regression test. Local build and D3D12 validation are pending.
- Added the current cross-fork evidence review. It records that the closest reported RTX 3070 results remain below 30 FPS, that the 4080 recipe includes unsafe/unmerged switches, and that the unified RTX 3070 descriptor-lifetime/MMU fix is now ported for local validation.
- No Release/diagnostic binary, shader cache, or gameplay benchmark was produced; `VICTORY_GAME_DIR` is unset and PresentMon is unavailable. No local game binary was available, so the runtime was not launched.

## 2026-11-26 — RTX 3070 investigation tools

- Added `tools/Collect-AstraForgeHardware.ps1`: reads OS, CPU, board, installed/available memory, DXGI adapter order and process-local DXGI budget; queries NVIDIA telemetry and D3D12 shader model, WaveOps/lane width, mesh shader, sampler feedback and ray-tracing tiers.
- Added `tools/Measure-AstraForgeGameplay.ps1`: captures PresentMon application presents, NVIDIA telemetry, per-process WDDM GPU memory counters on the NVIDIA adapter LUID, process memory, per-thread CPU, system physical/commit memory, and graphics-related System events.
- Extended `tools/Compare-AstraForgeRuns.ps1`: aggregate at least three repeated runs by their per-run median, require clean and consistent builds/environment, and reject unmatched scene, cache, resolution, hardware, or frame-type metadata. Only explicitly allowed runtime variables may differ between cohorts.
- Extended `tools/Measure-AstraForgeGameplay.ps1`: apply a source-bound RTX profile, validate recognized runtime override names, guard the NVIDIA adapter/commit budget, record operator-supplied resolution labels and executable hash, and stop capture processes on errors while leaving VIctory running after a successful capture.
- Added `tools/Build-AstraForge.ps1` and `tools/Prewarm-AstraForge.ps1`: guarded helpers for the pinned Cargo target/features and shader CLI. Build helper now defaults to the isolated source import.
- Changed the build helper to place each build in a unique external Cargo target directory and emit Release/diagnostic executable hashes plus a build manifest. `-ThinLto -NativeCpu` targets the Ryzen 7 7700X CPU submission path; A/B performance remains unmeasured. The launcher accepts the selected external executable with `-RuntimeExe`.
- Added explicit cache-seed prewarming and isolation: the prewarm tool pins `VICTORY_CACHE_DIR`, records a seed manifest, and the gameplay harness clones each warm seed into a unique per-run directory with content SHA-256 verification. Cold runs require an empty, unique cache at launch and state that scene setup can warm it before timing.
- Added `tools/Test-AstraForgeBenchmarkHarness.ps1` and `AstraForge-BenchmarkCommon.psm1`. Synthetic checks validate warm/cold comparison groups, seed copying and mutation detection, rejection of a changed seed, application-frame classification, and the per-run 30 FPS stability rule.
- Tightened real-frame accounting: if PresentMon supplies frame types but no Application frames, the harness now rejects the capture instead of counting unclassified/generated frames as rendered FPS.
- Added hardware/source assessment, a 35-variable audit of the current NVIDIA 8 GB source, rollback notes, and benchmark procedure documentation.
- Validated all PowerShell scripts and the common module; synthetic cache cloning/fingerprint tests and cold/warm three-run comparisons passed, including the 30 FPS target assessment and rejection of mismatched warm seeds. Live hardware detection and profile JSON also passed. These are tooling checks, not a VIctory build or gameplay performance result.

No 30 FPS result or measured gain from compiler flags is claimed. The ported DirectStorage/descriptor changes are separated into source commits but still require compilation and GPU validation. No generated binary, shader cache, game file, or save was produced. Upstream GPL-3.0 code and its authorship are preserved in the isolated source checkout; profile and import provenance are documented in [launcher-profiles.md](launcher-profiles.md) and `third_party/nvidia-3070-VI/LOCAL-CHANGES.md`.
## 2026-11-26 — GPU profiles and anonymous report export

- Added the manifest-driven NVIDIA RTX 3070 profile to `profiles/gpu-profiles.json`; AMD remains unconfigured. Startup and gameplay capture verify the selected adapter against that profile and the first DXGI adapter requirement of this renderer.
- Added `tools/Start-AstraForge.ps1` as the profile-driven entry point and retained `Start-AstraForge3070.ps1` as a compatibility wrapper. Shader prewarm and benchmark cache/data paths now include the profile identifier.
- Generalized gameplay summaries and A/B comparison cohorts to record and match the selected GPU profile and adapter LUID.
- Added an allowlist-based public benchmark exporter and synthetic privacy coverage. Public JSON omits local file/cache paths and raw capture filenames; anonymous scene labels are required.
- Updated launcher, benchmark, rollback, source-credit, and progress documentation. The copied launcher's data directory defaults to `%LOCALAPPDATA%\AstraForge\GameFiles`; its executable path is configurable without placing personal filenames in the project.
- Strengthened path guards so the profile launcher rejects game files, logs, cache, and data inside the whole workspace; build artifacts and shader prewarm logs/archives are also kept outside it.
- Git/GitHub CLI versions were checked. The stored GitHub CLI token is invalid and network access to GitHub is blocked in this environment; no public repository or remote has been created, and no files have been uploaded.
- PowerShell parsing and synthetic harness checks passed. Rust build and real GPU/gameplay validation remain pending.
