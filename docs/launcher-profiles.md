# RTX 3070 launcher and profiles

`tools/Start-AstraForge.ps1` selects a hardware profile from `profiles/gpu-profiles.json`, then applies one of its runtime tuning presets. The only current adapter profile is NVIDIA RTX 3070 Ampere. `tools/Start-AstraForge3070.ps1` remains a compatibility wrapper for that profile. The launcher checks adapter identity/order, D3D12 shader model, WaveOps, wave-lane range, dedicated memory, compute capability, and available commit before it starts VIctory. Game data, cache, and logs stay outside the source checkout.

Example after placing the source checkout and personal game files in their own directories:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\Start-AstraForge.ps1 `
  -SourceRoot 'D:\src\nvidia-3070-VI' `
  -GameDir 'D:\GameFiles' `
  -GpuProfile nvidia-rtx3070 `
  -Profile Balanced
```

The selected folder must contain the executable expected by this VIctory build. The source checkout must contain `crates\victory-gpu\src\resource.rs` with the audited `VICTORY_TEXTURE_ROOM_PERCENT` behavior. Use `-RuntimeExe` to select a Release artifact from the external build directory; otherwise the launcher checks the source checkout's `target\release\victory.exe` and packaged Pareto runner. The script stops when the chosen profile's adapter is not first in DXGI order, because this source has no explicit adapter override. Series S is the profile default; Series X requires the explicit `-AllowSeriesX` switch and monitoring for paging and device loss.

The launcher defaults to the neutral executable filename `game.exe`. If the local installation uses another filename, pass only that basename with `-GameExecutableName`; the folder is still selected separately through `-GameDir`. The command-file launcher also accepts a full executable path in `VICTORY_GAME_EXE`.

| Profile | Texture room | Intended tradeoff | Evidence |
|---|---:|---|---|
| Stability | 80% | More budget headroom; texture copies may wait longer | Candidate, unmeasured here |
| Balanced | 90% | Source default and closest to the measured 3070 Ti Series S baseline | Candidate, unmeasured here |
| Performance | 85% | Lower copy residency to limit paging; could increase streaming churn | Candidate, unmeasured here |
| Quality | 95% | More room for texture copies; less headroom on an 8 GB card | Candidate, unmeasured here |

The percentages are accepted by the audited source (50–97, default 90); they are not promised FPS settings. They are the only difference among profiles. `VICTORY_DISPLAY_MODE=1920x1080` reports the display mode; the fork's report found no frame-time change from that setting. The source has no separately verified 1280x720 render-scale/upscaler variable. Use the same replay, scene, cache state, and PresentMon capture for each candidate. Do not interpret the labels as measured rankings.

### Optional wait experiment

The source also accepts `VICTORY_FILL_TITLE=0`, `1`, or `2`. `0` (and unknown values) keeps the wait; `1` is the existing broader 64 KiB predicate; `2` is the narrower donor predicate, which skips the wait only when no shader write landed in that range during the prior 600 frames. The four supplied profiles do not set this variable. The donor's short A/B result is a hypothesis for this PC, not a guarantee. For a separate comparison, capture the unchanged profile first, then set `VICTORY_FILL_TITLE=2` for a matched run; inspect image correctness, stale constants, device errors, and frametime before considering any preset change. Omit the variable or set `0` to restore the baseline.

The preflight requires at least 12 GiB of available commit by default. It warns below 20 GiB because a separate 3070 Ti/64 GiB run used about that much in-world, but that is not a prediction for this PC. `-AllowLowCommit` bypasses only the 12 GiB stop; it does not guarantee the game will fit. For a deliberate Series X trial, pass `-Console series-x -AllowSeriesX` and keep the run short while monitoring for paging and device loss.

After the run, inspect `victory.stderr.log`, `memory.csv`, and `gpu-process-memory.csv` in that run's directory. For frame-time percentiles and per-thread/GPU traces use `tools/Measure-AstraForgeGameplay.ps1` with PresentMon and the same `-GpuProfile`, following [the benchmark procedure](benchmark-procedure.md). The public-report exporter emits an allowlisted JSON without local capture/cache paths; inspect it before sharing. The benchmark creates isolated cold caches and clones immutable warm seeds; it never deletes the user's existing cache, saves, or game files.

## Source credit

The baseline environment values and the Series S invocation come from `Play-VIctory.cmd` and `scripts/play-guarded.ps1` in [`grimygunnz/nvidia-3070-VI`](https://github.com/grimygunnz/nvidia-3070-VI), imported at `6e9c1dd9fb32daaa855f446560a4d1f8df5f8424`, descended from the requested COOL_FOX Pareto-residency commit. Current upstream `25ff216` is a docs-only update. The profile-only setting's parser and 50–97 bounds were verified in the imported `crates/victory-gpu/src/resource.rs`. The workspace retains the source's GPL-3.0 license and its local change log lists each code port and its origin.
