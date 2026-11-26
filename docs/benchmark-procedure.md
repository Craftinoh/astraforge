# AstraForge gameplay benchmark procedure

The harness measures actual PresentMon presents for the game executable when it is a separate process; if it is loaded into the compatibility runtime, it captures the runtime PID. It prompts the operator to reach a reproducible gameplay scene before timing begins. Menus and loading screens should not be used as scenarios.

## Requirements

- A built `victory.exe` from the exact source revision under test. The local checkout is `third_party\nvidia-3070-VI`; source builds, profiles, and benchmark summaries must record the nested Git commit.
- Personal game executable and data outside the source repository.
- PresentMon v2 command-line executable.
- NVIDIA `nvidia-smi` for GPU/clock/power telemetry.
- Windows GPU Process Memory / GPU Engine performance counters. The harness degrades gracefully if those counters are unavailable.

## Build and shader prewarm

The guarded build helper reads the checkout's `rust-toolchain.toml`, checks the Windows MSVC target and the `victory` package, then builds Release and the repository's `diag` + `diagnostics` variant:

```powershell
.\tools\Build-AstraForge.ps1 -Mode Both
```

The per-machine optimized candidate is:

```powershell
.\tools\Build-AstraForge.ps1 -Mode Both -ThinLto -NativeCpu
```

It enables Rust Thin LTO and the Ryzen 7 7700X's native instruction target, including AVX2 where supported. Thin LTO is a compile-time option and is unrelated to runtime `VICTORY_THIN`. A default build can be produced separately with `-Mode Both`; each build receives a unique target/artifact directory outside the checkout, so the Release and diagnostic executables do not overwrite one another. The helper emits a manifest with source commit, flags, and executable hashes. These compiler options may reduce CPU-side submission and shader preparation overhead, but the gameplay effect is unmeasured until the same route is benchmarked. It has not completed here: Cargo/rustc, MSVC, and DXC are unavailable. The first build attempt stopped at the missing `cargo.exe` before compiling any code.

Pass the Release artifact printed by the build helper to the profile launcher; changing runtime profiles does not require another build:

```powershell
.\tools\Start-AstraForge3070.ps1 `
  -RuntimeExe "$env:LOCALAPPDATA\AstraForge\builds\artifacts\<build-id>\cargo-target\release\victory.exe" `
  -GameDir 'D:\GameFiles' `
  -Profile Balanced
```

The prewarm helper first asks the selected binary whether it exposes `shaders` and `warm` commands, then runs only the commands it found:

```powershell
.\tools\Prewarm-AstraForge.ps1 `
  -RuntimeExe "$env:LOCALAPPDATA\AstraForge\builds\artifacts\<build-id>\cargo-target\release\victory.exe" `
  -SourceRoot '.\third_party\nvidia-3070-VI' `
  -GpuProfile nvidia-rtx3070 `
  -ShaderArchives @('D:\GameFiles\archive-1', 'D:\GameFiles\archive-2') `
  -CacheDirectory "$env:LOCALAPPDATA\AstraForge\shader-cache-seed-<build-id>" `
  -WarmUsedPipelines
```

Provide the shader-archive paths documented by that checkout; the helper does not guess them. It rejects paths that overlap the source repository, archives, or log directory, pins `VICTORY_CACHE_DIR` to the requested seed path for compilation, and writes a manifest with the executable hash and cache fingerprint. Existing seed files are retained; the helper never clears the seed.

## Capture

Run from this workspace:

```powershell
Start-Process "$env:WINDIR\System32\dxdiag.exe" -ArgumentList @('/t', (Join-Path $PWD 'out\dxdiag.txt')) -Wait
.\tools\Collect-AstraForgeHardware.ps1 -DxDiagReportPath .\out\dxdiag.txt -OutputPath .\out\hardware.json
.\tools\Measure-AstraForgeGameplay.ps1 `
  -RuntimeExe 'D:\AstraForge\target\release\victory.exe' `
  -GameExe 'D:\GameFiles\game.exe' `
  -GpuProfile nvidia-rtx3070 `
  -PresentMonExe 'D:\Tools\PresentMon.exe' `
  -Scenario 'scene-01' `
  -Console series-s `
  -Profile Balanced `
  -BuildLabel 'commit-or-build-name' `
  -SourceRoot 'D:\AstraForge' `
  -CacheState cold `
  -InternalResolutionLabel '<measured-width>x<measured-height>' `
  -OutputResolutionLabel '<measured-width>x<measured-height>' `
  -DurationSeconds 600
```

The harness clears inherited `VICTORY_*` values, applies the selected GPU and tuning profiles, then restores the caller's environment at exit. It loads the NVIDIA profile requirements from `profiles/gpu-profiles.json`, checks that the selected NVIDIA adapter is first in DXGI order, and validates D3D12 shader model, WaveOps/lane width, compute capability, dedicated memory, and available commit. It validates the profile's source manifest and the implemented `VICTORY_TEXTURE_ROOM_PERCENT` range. The optional `-RuntimeOverride @{ VICTORY_THIN = '0' }` applies one additional setting; each override name must appear in Rust source, and it is recorded in the run. This is a name-presence check, not a generic parser for every variable's value range, so use values documented in [the variable audit](RTX3070-variable-audit.md). The game executable must resolve outside this repository. Use only a neutral scenario alias such as `scene-01`; the harness rejects labels that do not follow this pattern and omits the executable path/name from the summary. Keep route/save details in local notes, never in a public report. Replace both resolution labels with measured pixel dimensions in `WIDTHxHEIGHT` form; the harness cannot detect internal render resolution and will not validate those labels. Outputs, cache, and data default outside the source checkout and game directory. The harness does not delete existing caches or game files. A cold run gets a new cache path and records that it was empty before VIctory launched. Manual scene setup happens before the timed interval and can compile shaders or populate that cache, so this is evidence of a fresh process cache, not a guarantee that timed frames include first-use compilation.

To make a reproducible warm run, close VIctory after the capture, then use the populated `CacheDirectory` from its summary as an immutable seed. Every warm run copies that seed into a new, isolated working directory and records its SHA-256 fingerprint. The seed, existing user caches, and saves remain untouched:

```powershell
.\tools\Measure-AstraForgeGameplay.ps1 `
  -RuntimeExe 'D:\AstraForge\target\release\victory.exe' `
  -GameExe 'D:\GameFiles\game.exe' `
  -PresentMonExe 'D:\Tools\PresentMon.exe' `
  -Scenario 'scene-01' `
  -Console series-s `
  -Profile Balanced `
  -BuildLabel 'commit-or-build-name' `
  -SourceRoot 'D:\AstraForge' `
  -CacheState warm `
  -CacheSeedDirectory '$env:LOCALAPPDATA\AstraForge\cache-cold-...' `
  -InternalResolutionLabel '1280x720' `
  -OutputResolutionLabel '1920x1080' `
  -DurationSeconds 600
```

Use the same seed fingerprint for repeated runs within each build/settings cohort. Make a separate seed for another source build if its pipeline cache is incompatible. The comparator requires a unique working cache directory per run and identical seed fingerprints within each warm cohort. The resolution values above are examples; verify actual dimensions before labeling a capture. This source does not expose a verified 720p internal render/upscaler setting, so do not label it 1280x720 unless runtime logs or a frame capture confirm it.

Before launch, the harness verifies the first DXGI adapter is an RTX 3070 and requires at least 12 GiB of available commit by default. `-AllowLowCommit` bypasses that guard explicitly. Series X also requires `-AllowSeriesX` on this 8 GB target.

Use repeatable manual routes for scene types such as interiors, vegetation, water, and dense crowds/traffic. Give each route an anonymous alias (`scene-01`, `scene-02`, etc.). Keep exact route/save/camera notes locally. For each source/settings change, run the same 600-second warm route at least three times; report the median of run summaries and keep each individual run locally. Capture startup/first-use shader or pipeline work separately; the timed gameplay segment begins only after manual scene setup. Compare Series S and Series X only after confirming the selected build's upscaler and compositor work in both.

The capture directory contains frame CSV, GPU telemetry, per-process GPU counters, process memory, per-thread CPU samples, adapter/hardware JSON, captured environment settings (secret-like variable names are excluded), runtime stdout/stderr, PresentMon stderr, and System log entries from Display/NVIDIA/DxgKrnl providers. The summary records the runtime executable's SHA-256. FPS and frametime percentiles use `MsBetweenPresents` for application frames; simulation-start cadence is reported separately. `FrameTypeClassified` indicates whether PresentMon could distinguish application and generated frames. When it cannot, the capture remains available for diagnosis, but the comparator refuses to treat the run as a real-frame result.

The PresentMon flags and frame fields follow its current console documentation; `--track_frame_type` is a beta option and only classifies generated frames when the app/driver provides instrumentation. [PresentMon console reference](https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md).

## Compare

```powershell
.\tools\Compare-AstraForgeRuns.ps1 `
  -BaselineSummary @('...\baseline-1\summary.json', '...\baseline-2\summary.json', '...\baseline-3\summary.json') `
  -CandidateSummary @('...\candidate-1\summary.json', '...\candidate-2\summary.json', '...\candidate-3\summary.json') `
  -AllowedEnvironmentDifference 'VICTORY_TEXTURE_ROOM_PERCENT' `
  -OutputPath '.\out\comparison.json'
```

By default, the comparator requires at least three summaries per group, clean and consistent source commits, matched hardware, scene, camera label, duration, console profile, both resolution labels and cache state. It rejects GPU frame capture where PresentMon did not classify application frames, and it records the median of each per-run metric rather than pooling all frames. Repeated captures in one group must have identical runtime settings and warm-seed fingerprints; cross-group environment changes must be listed in `AllowedEnvironmentDifference`. It marks the 30 FPS stability target passed only when every candidate run has application median FPS and 1% low FPS at or above 30 (p99 frametime at or below 33.333 ms). The harness does not automate camera movement or game inputs, so the scene must be reproduced manually. GPU performance counters are WDDM system counters; their paths include adapter LUIDs, and different engine instances must not be summed blindly. `nvidia-smi` utilization, power, clocks, and dedicated-memory totals are system-wide.

Run the synthetic harness checks before collecting real gameplay data:

```powershell
.\tools\Test-AstraForgeBenchmarkHarness.ps1
```

These checks cover cold/warm cohort validation, seed cloning/fingerprints, invalid warm-seed rejection, and the 30 FPS assessment. They do not build VIctory or predict GPU performance.

The scripts collect frame time, FPS and lows, GPU utilization/clocks/power/memory, GPU process memory counters, VIctory/game working set and commit, CPU thread deltas, and graphics-related event logs. Draw counts, missing PSOs, shader compilation duration, texture residency decisions, and render artifacts must be emitted by the exact engine build or reviewed in a frame capture; this generic harness cannot infer them from PresentMon.
## Public report

After reviewing the local comparison, create a shareable allowlisted report with:

```powershell
.\tools\Export-AstraForgePublicReport.ps1 `
  -ComparisonPath '.\out\comparison.json' `
  -OutputPath '.\out\public-benchmark.json'
```

The exporter rebuilds the report from approved fields. It retains the anonymous scene alias, hardware summary, build/source hashes, and performance metrics while omitting local summary/cache paths, raw telemetry, executable names, and runtime paths. It rejects non-anonymous scene labels and path-like build labels. Inspect the output before sharing; the source comparison and raw captures remain local and ignored by Git.
