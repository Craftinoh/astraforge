# AstraForge

An open-source Windows compatibility layer built around architecture-aware GPU profiles. NVIDIA Ampere is the first target. AMD support is a later, separately tested phase.

The goal is to move beyond a typical vibe-coded emulator fork: make the implementation, build, GPU profiles, measurements, attribution, limitations, and rollback process clear enough that other compatibility projects can use them as a model.

## Project status

- Source baseline: COOL_FOX Pareto-residency, through the NVIDIA 8 GB derivative.
- Current hardware profile: desktop NVIDIA GeForce RTX 3070, Ampere GA104, 8 GB.
- Runtime presets: Stability, Balanced, Performance, Quality. They are candidates, not benchmarked rankings.
- Acceptance target: at least 30 real application FPS with a 1% low of at least 30 in repeated gameplay captures. No result is claimed until measured.
- AMD: not implemented or enabled yet. Its profile and adapter path will be developed and validated separately.

## GPU profile layout

`profiles/gpu-profiles.json` identifies supported hardware independently from its runtime tuning presets. `profiles/rtx3070-profiles.json` holds the current NVIDIA settings. This separation lets the project add GPU-specific profiles without mixing vendor assumptions or reusing unverified tuning values.

## Build and run

Requirements include the repository-pinned Rust toolchain, Windows MSVC build tools, Windows SDK, DirectX Shader Compiler, the imported engine source, PresentMon for gameplay measurements, and personally owned game data installed outside this repository.

```powershell
.\tools\Build-AstraForge.ps1 -Mode Both -ThinLto -NativeCpu
.\tools\Start-AstraForge.ps1 -GpuProfile nvidia-rtx3070 -Profile Balanced `
  -RuntimeExe "$env:LOCALAPPDATA\AstraForge\builds\artifacts\<build-id>\cargo-target\release\victory.exe" `
  -GameDir 'D:\GameFiles' -GameExecutableName 'game.exe'
```

The source targets the first DXGI adapter. The NVIDIA profile launcher checks that the RTX 3070 is first before starting the renderer. Thin LTO and native CPU code generation are build candidates for the Ryzen 7 7700X CPU submission path; their performance effect is not yet measured.

See [the project vision](docs/project-vision.md), [the progress journal](docs/progress-journal.md), [the launcher profiles](docs/launcher-profiles.md), [the benchmark procedure](docs/benchmark-procedure.md), and [the source credits](docs/source-credits.md).

## Anonymous benchmark policy

Public benchmark summaries use aliases such as `scene-01` and `scene-02`. They omit the game title, executable name, personal file paths, save identifiers, and raw logs that could reveal them. Internal captures remain local; create a reviewed, sanitized report with `tools/Export-AstraForgePublicReport.ps1` before sharing.

No game binaries, dumps, keys, personal saves, caches, private credentials, or raw hardware inventory belong in this repository. `.gitignore` excludes local captures and common game-data paths.

## Attribution and license

The source is GPL-3.0. Keep upstream copyright notices and the local change ledger with every source change. See [source credits and provenance](docs/source-credits.md) and `third_party/nvidia-3070-VI/LOCAL-CHANGES.md`. This is an independent community project and is not affiliated with NVIDIA, AMD, Microsoft, or the upstream VIctory maintainers.

## Verification limits

PowerShell harness checks pass locally. This environment has not produced a Release or diagnostic binary and has not captured gameplay FPS. Local runtime compatibility still needs to be checked before gameplay testing. Treat the 30 FPS target as an acceptance criterion, not a performance promise.
