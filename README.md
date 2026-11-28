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

## Status — `v0.1.2-preview` (pre-release, 2026-11-28)

Tested on one PC: RTX 3070 8 GB, Ryzen 7 7700X, 32 GiB RAM, Windows 11, Series S profile, 1280x720, Stability preset.

| Area | State |
|---|---|
| Start-up screens, menus, story loading | ✅ Visible |
| Entering a high-draw scene | ⚠️ Four exploratory 120 s captures on this source reached the scene without a runtime crash. Longer sessions and further routes remain unverified. The RTX 3070 profile lets the title's own hang watchdog wait 120 s (`VICTORY_WATCHDOG_SECONDS`); a real hang is still stopped |
| Character skin | ⚠️ Intermittent: correct in some runs, black in others with the same settings. Skin-bake sources are now refreshed before each bake (fxceless port), which fixes one cause but not all |
| Textures and colours | ⚠️ Flickering and black or missing materials remain. The BCPack BC7 dictionary-index fix passed byte-exact reference checks; its effect in play has not been isolated |
| Performance | ⚠️ Four exploratory 120 s PresentMon captures on the current source classified application frames. Two Release runs measured 8.05 and 19.87 fps average, with 1% lows of 1.08 and 3.32. Scene and cache variation prevent a performance-gain claim; the 30 fps target is unverified |
| Host memory | ⚠️ The Release runs peaked at 19.08–19.28 GiB of process-private memory and left as little as 3.31–3.54 GiB of commit available. A 16 GiB RAM host has not been validated |
| VRAM on 8 GB cards | ⚠️ Keep the Stability preset (80 % texture room). 90 % measured 5.2 fps and 94 % measured 2.1 fps |
| DLSS and frame generation | ❌ Not integrated in this checkout |
| PresentMon frame capture | ⚠️ All four new captures wrote classified CSVs. Earlier sessions sometimes lost ETW events and produced no CSV |
| Other GPUs | ❌ Not supported yet. A candidate RTX 3060 profile is in review as a separate identity |

The acceptance target is at least 30 real application FPS with a 1% low of at least 30,
measured over repeated gameplay captures. It has **not** been reached. Details are in
the [release notes](docs/releases/v0.1.2-preview.md) and the [progress journal](docs/progress-journal.md).

## Quick start

1. **Clone this repository** from the [v0.1.2-preview release](https://github.com/Craftinoh/astraforge/releases). This preview is source-only; build the runtime with the helper below.
2. **Launch** with your own application directory, using the Stability profile and 720p:

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
dirty flag and SHA-256 hashes, and remaps Rust source paths. The runtime still embeds
a compile-time source directory, so check any executable before sharing it. After a
successful build, the helper removes older managed build
directories under the artifact root and keeps the new build. Logs, caches and pre-warm
data are left alone. Pre-warm the shader cache for a new build with
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

1. Texture admission and reuse: in one diagnostic run the texture queue reported no room in 28 of 34 samples, with 596 textures still waiting and 826 MB free in pieces inside texture blocks. Reduce stranded room and duplicate copies while preserving rendering and the card budget.
2. Reduce host memory and copy-back. The RTX 3070 profile leaves large shader writes into write-combined title memory on the card. Smaller title-memory windows saved about 600 MB in earlier runs but are still experimental; a combined RAM variant showed alternating bright and black frames and was stopped.
3. Hardening: synchronous `MakeResident` can stall loading near the card budget. Fix it without losing residency safety.
4. Then frame time: the single submit thread and the copy-back of shader results. The title marks when shader results must reach the CPU (level-2 cache write-backs in its syncs). Copying back only then is a candidate, pending correctness evidence.
5. Black skin, walls and objects: they are black already in the albedo target in earlier captures. More texture room on 8 GB made the card page and stall, so card memory must shrink first.
6. Make PresentMon capture reliable under ETW event loss.

Rejected on 2026-11-28 after measurement: write-watched private allocations (Vice-Tay #321), turning the texture-block gate off, and a system-memory texture tier. See the [progress journal](docs/progress-journal.md).

The [operational plan](docs/OPERATIONAL_PLAN.md) has the full queue. The current
[Qwen Coder handoff](docs/QWEN_CODER_HANDOFF.md) is written for continuing agents;
the older [Claude Code handoff](docs/CLAUDE_CODE_HANDOFF.md) is retained as history.

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
