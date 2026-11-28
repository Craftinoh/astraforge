# AstraForge

**An open, evidence-first Windows compatibility layer for Xbox Series titles, organized
around architecture-aware GPU profiles.** NVIDIA Ampere (RTX 3070) is the first and only
validated target. AMD support is a later, separately tested phase.

[![Release](https://img.shields.io/github/v/release/Craftinoh/astraforge?include_prereleases&label=release)](https://github.com/Craftinoh/astraforge/releases)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

AstraForge integrates focused fixes from the open VIctory fork family under one documented
contract: every change records its source, its tests and its limits, and no performance
claim is made without a real capture. The goal is that a contributor can add a GPU profile
or a focused engine patch without copying a whole fork or losing authorship and evidence.

> **No game files are included or accepted.** You need your own legally owned copy,
> installed outside this repository. Public reports never name the game; they use
> anonymous scene labels such as `scene-01`.

## Status — `v0.1.1-preview` (pre-release, 2026-11-27)

Tested on one PC: RTX 3070 8 GB, Ryzen 7 7700X, 32 GiB RAM, Windows 11, Series S profile, 1280x720, Stability preset.

| Area | State |
|---|---|
| Start-up screens, menus, story loading | ✅ Visible |
| Entering the world and playing the first story scene | ✅ No crash in 10 automated runs, each 2–3 minutes in the world and 6 of them on this release's source. A warmed shader cache and pipeline library were used. ⚠️ Longer sessions can stop after about 5 minutes: the title's own watchdog ends it when its update loop makes no progress for about 30 s, seen during long loading stalls (under investigation) |
| Character skin | ⚠️ Intermittent: correct in some runs, black in others with the same settings. Skin-bake sources are now refreshed before each bake (fxceless port), which fixes one cause but not all |
| Textures and colours | ⚠️ Flickering; some materials and colours missing |
| Performance | ⚠️ Low and CPU-bound. The runtime's internal reports show 10–12 fps on average. One PresentMon capture measured 9.8 fps average, 11.6 median and 2.4 for the 1% low. Each frame spends about 55–70 ms of CPU preparation, 30–36 ms copying results back and 7–13 ms on the GPU |
| VRAM on 8 GB cards | ⚠️ Keep the Stability preset (80 % texture room). 90 % measured 5.2 fps and 94 % measured 2.1 fps |
| PresentMon frame capture | ⚠️ Works with the official PresentMon 2.x, but often loses ETW events in this workload and then writes no CSV |
| Other GPUs | ❌ Not supported yet. A candidate RTX 3060 profile is in review as a separate identity |

The acceptance target is at least 30 real application FPS with a 1% low of at least 30,
measured over repeated gameplay captures. It has **not** been reached. Details are in
the [release notes](docs/releases/v0.1.1-preview.md) and the [progress journal](docs/progress-journal.md).

## Quick start

1. **Download** `astraforge-v0.1.1-preview-win64.zip` from
   [Releases](https://github.com/Craftinoh/astraforge/releases) and check it against `SHA256SUMS.txt`.
2. **Clone this repository**. The launcher, profiles and preflight checks live here.
3. **Launch** with your own game directory, using the Stability profile and 720p:

```powershell
.\tools\Start-AstraForge3070.ps1 -Profile Stability -Console series-s `
  -RuntimeExe 'C:\path\to\victory.exe' `
  -GameDir 'D:\GameFiles' -GameExecutableName 'game.exe' `
  -RuntimeOverride @{ VICTORY_DISPLAY_MODE = '1280x720' }
```

The launcher refuses to start unless the RTX 3070 is the first DXGI adapter and at least
12 GiB of commit memory is free. Logs, caches and data stay outside both the repository
and the game folder.

**First launch after a new build or cache:** the first story load may still stall while
pipelines are compiled, and the game's own watchdog can close it. Launch again: the
pipeline library is saved during the run, and the next launch loads it.

## Build from source

Requirements: the pinned Rust toolchain (`third_party/nvidia-3070-VI/rust-toolchain.toml`), MSVC build tools and the
Windows SDK. For gameplay measurement you also need PresentMon.

```powershell
.\tools\Build-AstraForge.ps1 -Mode Both -ThinLto            # portable Release + diagnostic
.\tools\Build-AstraForge.ps1 -Mode Both -ThinLto -NativeCpu # local-only, tuned to this CPU
```

The helper builds outside the repository, writes a manifest with the source commit, a
dirty flag and SHA-256 hashes, and remaps source paths so a shared binary carries no
personal directories. Pre-warm the shader cache for a new build with
`tools/Prewarm-AstraForge.ps1` (see the [benchmark procedure](docs/benchmark-procedure.md)).

## How the project is organized

| Path | Purpose |
|---|---|
| `third_party/nvidia-3070-VI/` | Imported engine source (Git subtree) and its [local change ledger](third_party/nvidia-3070-VI/LOCAL-CHANGES.md) |
| `profiles/gpu-profiles.json` | Hardware identity and launcher preflight, kept separate from tuning |
| `profiles/rtx3070-profiles.json` | RTX 3070 runtime presets: Stability, Balanced, Performance and Quality. All are unbenchmarked candidates |
| `tools/` | Build, launch, prewarm, hardware collection, capture, comparison, public-report export |
| `docs/` | Plan, journal, procedures, provenance, contributor guides |

Keeping hardware identity separate from tuning means a new GPU gets its own profile and
its own evidence. Values are never inherited from another card as if they had been measured.

## Contributing

All contributions are welcome, including a plain hardware report with no code.

- **New GPU or PC:** follow the [GPU profile submission gate](docs/GPU_PROFILE_SUBMISSION.md)
  and the [hardware report template](docs/templates/hardware-report.template.md). A new card
  gets its own profile (for example `nvidia-rtx3060`); `nvidia-rtx3070` is not reused.
- **Engine or shader fix:** keep it focused, record its upstream source in
  [source credits](docs/source-credits.md) and the subtree ledger, and include tests.
- **Performance numbers:** follow the [benchmark procedure](docs/benchmark-procedure.md).
  A window caption or an overlay is a useful hint, but it is not a measurement.
- **Coding agents** must follow [AGENTS.md](AGENTS.md); see the
  [AI contributor guide](docs/AI_CONTRIBUTOR_GUIDE.md) and the [task brief](docs/templates/AI_TASK_PROMPT.md).

Start at [CONTRIBUTING.md](CONTRIBUTING.md). Pull requests use
`.github/PULL_REQUEST_TEMPLATE.md`. For splitting work between a GPU validator and the
maintainer, see the [contributor handoff](docs/CONTRIBUTOR_HANDOFF.md).

## Current priorities

1. Hardening: the title stops itself when no frame completes for about 30 s (its own watchdog). The cause found is synchronous `MakeResident` for new textures and targets while the card is near its budget, during loading. Fix it without losing the residency safety it gives.
2. Reduce duplicate memory and copy-back. The RTX 3070 profile now leaves large shader writes into write-combined title memory on the card (VIctory-NVIDIA port): about a third less copy-back. Smaller title-memory windows saved about 600 MB but are off again until loading no longer blocks on residency.
3. Then frame time: the single submit thread and the copy-back of shader results.
4. Black skin, walls and objects: a captured frame shows them black already in the albedo target while about 21,000 textures wait for card room. Giving textures more room on 8 GB caused paging stalls (0.1–1.6 fps), so memory must be freed first.
5. Make PresentMon capture reliable under ETW event loss.

Rejected on 2026-11-28 after measurement: write-watched private allocations (Vice-Tay #321), turning the texture-block gate off, and a system-memory texture tier. See the [progress journal](docs/progress-journal.md).

The [operational plan](docs/OPERATIONAL_PLAN.md) has the full queue. The
[Claude Code handoff](docs/CLAUDE_CODE_HANDOFF.md) is written for continuing agents.

## Privacy and benchmark policy

Public summaries use aliases such as `scene-01`, and leave out the game title, executable
name, personal paths, save identifiers and raw logs. Create a reviewed report with
`tools/Export-AstraForgePublicReport.ps1` before sharing. No game binaries, dumps, keys,
saves, caches, credentials or raw hardware inventories belong in this repository.

Optional AI-assisted review (`tools/Invoke-AstraForgeModelReview.ps1`) sends only
explicitly selected public source files and keeps keys and responses outside Git; see the
[model orchestration guide](docs/MODEL_ORCHESTRATION.md). Model output is a hypothesis to
verify, never evidence by itself.

## Credits and license

GPL-3.0. AstraForge builds on the VIctory fork family, including the COOL_FOX
Pareto-residency line, the NVIDIA 8 GB derivative, Vice-Tay, trustno's NVIDIA fork and
others. Exact commits and authors are listed in [source credits](docs/source-credits.md).
This is an independent community project and is not affiliated with NVIDIA, AMD,
Microsoft, any game publisher, or the upstream VIctory maintainers.
