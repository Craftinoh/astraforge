# AstraForge

An open-source Windows compatibility layer built around architecture-aware GPU profiles. NVIDIA Ampere is the first target. AMD support is a later, separately tested phase.

The goal is to move beyond a typical vibe-coded emulator fork: make the implementation, build, GPU profiles, measurements, attribution, limitations, and rollback process clear enough that other compatibility projects can use them as a model.

Among the upstream forks reviewed for this work, AstraForge is the only project organized around integration itself: hardware support, runtime tuning, source provenance, validation, and public evidence follow one documented contract. The aim is to let contributors add a GPU profile or a focused engine patch quickly, without copying an entire vendor fork or losing authorship and test evidence. AstraForge is being built to become a reusable standard for open compatibility projects.

## Project status

- Source baseline: COOL_FOX Pareto-residency, through the NVIDIA 8 GB derivative.
- Current hardware profile: desktop NVIDIA GeForce RTX 3070, Ampere GA104, 8 GB.
- Runtime presets: Stability, Balanced, Performance, Quality. They are candidates, not benchmarked rankings.
- Acceptance target: at least 30 real application FPS with a 1% low of at least 30 in repeated gameplay captures. No result is claimed until measured.
- AMD: not implemented or enabled yet. Its profile and adapter path will be developed and validated separately.

## GPU profile layout

`profiles/gpu-profiles.json` identifies supported hardware independently from its runtime tuning presets. `profiles/rtx3070-profiles.json` holds the current NVIDIA settings. This separation lets the project add GPU-specific profiles without mixing vendor assumptions or reusing unverified tuning values.

## Bring your own hardware and coding model

Contributors can bring a different PC specification without claiming that its GPU is already supported. Start at [CONTRIBUTING.md](CONTRIBUTING.md), collect a reviewed, sanitized inventory with the [hardware intake template](docs/templates/hardware-report.template.md), and follow the [GPU profile submission gate](docs/GPU_PROFILE_SUBMISSION.md). Hardware identity, adapter support, and runtime presets have separate acceptance requirements.

Coding agents must follow [AGENTS.md](AGENTS.md). The [AI contributor guide](docs/AI_CONTRIBUTOR_GUIDE.md) explains the source tree, validation levels, provenance, privacy rules, and includes a task prompt. Copy [the task brief](docs/templates/AI_TASK_PROMPT.md) for each model-assisted change. Pull requests use the repository checklist in `.github/PULL_REQUEST_TEMPLATE.md`.

## Build and run

Requirements include the repository-pinned Rust toolchain, Windows MSVC build tools, Windows SDK, DirectX Shader Compiler, the imported engine source, PresentMon for gameplay measurements, and personally owned game data installed outside this repository.

```powershell
.\tools\Build-AstraForge.ps1 -Mode Both -ThinLto -NativeCpu
.\tools\Start-AstraForge.ps1 -GpuProfile nvidia-rtx3070 -Profile Balanced `
  -RuntimeExe "$env:LOCALAPPDATA\AstraForge\builds\artifacts\<build-id>\cargo-target\release\victory.exe" `
  -GameDir 'D:\GameFiles' -GameExecutableName 'game.exe'
```

The source targets the first DXGI adapter. The NVIDIA profile launcher checks that the RTX 3070 is first before starting the renderer. Thin LTO and native CPU code generation are build candidates for the Ryzen 7 7700X CPU submission path; their performance effect is not yet measured.

See [the project vision](docs/project-vision.md), [the integration architecture](docs/integration-architecture.md), [the progress journal](docs/progress-journal.md), [the launcher profiles](docs/launcher-profiles.md), [the benchmark procedure](docs/benchmark-procedure.md), and [the source credits](docs/source-credits.md).

## Anonymous benchmark policy

Public benchmark summaries use aliases such as `scene-01` and `scene-02`. They omit the game title, executable name, personal file paths, save identifiers, and raw logs that could reveal them. Internal captures remain local; create a reviewed, sanitized report with `tools/Export-AstraForgePublicReport.ps1` before sharing.

No game binaries, dumps, keys, personal saves, caches, private credentials, or raw hardware inventory belong in this repository. `.gitignore` excludes local captures and common game-data paths.

## Contributor review workflow

AI-assisted review is optional. A first-pass coding review can run through OpenCode with the currently listed `opencode/deepseek-v4.1-flash-free` model; free-model availability is controlled by its provider and can change. Keep reviews focused on source files and public documentation, never include credentials or personal game data, and verify every proposed change against the full call path, build, and tests. Model output is review input, not correctness or performance evidence. No provider key is stored in this repository.

```powershell
opencode run --model opencode/deepseek-v4.1-flash-free `
  "Review the current diff for concrete D3D12 lifetime and RTX 3070 risks. Do not edit files; cite exact paths and lines."
```

See the [OpenCode model guide](https://opencode.ai/docs/console/models/) for the current model catalog and [DeepSeek's OpenCode setup guide](https://api-docs.deepseek.com/quick_start/agent_integrations/opencode/) for a separate, user-key-based DeepSeek API connection.

## Attribution and license

The source is GPL-3.0. Keep upstream copyright notices and the local change ledger with every source change. See [source credits and provenance](docs/source-credits.md) and `third_party/nvidia-3070-VI/LOCAL-CHANGES.md`. This is an independent community project and is not affiliated with NVIDIA, AMD, Microsoft, or the upstream VIctory maintainers.

## Verification limits

The pinned Rust/MSVC toolchain and local D3D12 tests are verified. The clean Release and diagnostic artifacts and their manifest are under `%LOCALAPPDATA%\AstraForge\builds\artifacts\20261127-005831-Both-thinlto-native-c8d108a7`; test totals are in the progress journal. No gameplay FPS capture exists yet, so runtime compatibility, visual quality, and the 30 FPS target remain unverified.
