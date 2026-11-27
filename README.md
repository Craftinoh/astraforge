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

## Status — `v0.1.0-preview` (pre-release)

Tested on one PC: RTX 3070 8 GB, Ryzen 7 7700X, 32 GiB RAM, Windows 11, Series S profile.

| Area | State |
|---|---|
| Start-up screens, menus, story loading | ✅ Visible (black output fixed in this release) |
| Entering the world without a crash | ✅ After one warm-up launch (pipeline library) |
| Textures and colours | ⚠️ Stream in slowly; colours/materials largely missing; some characters black; flickering |
| Performance | ⚠️ Low. Users reported about 7–9 average frames/s in story and at sea (not a PresentMon measurement) |
| CPU load | ⚠️ High even in menus; about 95 ms/frame spent translating command lists (first optimization target) |
| PresentMon frame capture | ❌ Not working yet, so **no validated FPS figure exists** |
| Other GPUs | ❌ Not supported yet. RTX 3060 testing is in progress as a separate profile |

The acceptance target is at least 30 real application FPS with a 1% low of at least 30,
measured over repeated gameplay captures. It has **not** been reached. Details are in
the [release notes](docs/releases/v0.1.0-preview.md) and the [progress journal](docs/progress-journal.md).

## Quick start

1. **Download** `astraforge-v0.1.0-preview-win64.zip` from
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

1. Reduce the per-frame CPU cost of command-list translation (`VICTORY_THIN` A/B).
2. Fix texture streaming, black characters and missing colours (decoration-bake texture uploads).
3. Get PresentMon capture working and record the first validated gameplay baseline.
4. Port the sampler-table fix (trustno PR #18) to replace `VICTORY_LIBRARY_STATIC_SAMPLERS=1`.

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
