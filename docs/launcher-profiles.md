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

Pass `-DebugConsole` to open a second, visible PowerShell window that follows both runtime output streams while the render window remains separate. The same output is retained in `victory.stdout.log` and `victory.stderr.log` under the external run directory. Closing the diagnostic console does not stop the runtime; closing the render process ends the monitored run normally. This switch changes observability only and is not a performance preset.

Pass `-PreRunWindow` to show a concise Windows checklist before launch. It reports the selected profile, artifact hash, cache readiness, first DXGI adapter/D3D12 capabilities, sampled VRAM, free RAM and commit headroom, then starts the runtime automatically after the checks pass. Closing the window before launch cancels the run. The window minimizes after startup so it does not cover the render window; controller input remains manual.

Each launcher run keeps runtime stdout/stderr, 5-second process/RAM/commit/thread samples, 5-second per-process GPU memory and engine counters when Windows exposes them, continuous 1-second `nvidia-smi` utilization/clocks/power/temperature/VRAM samples, and relevant Windows graphics/system events in its external run directory. Missing performance counters or `nvidia-smi` telemetry are recorded as unavailable where possible and do not create fabricated values. The runtime's own `VICTORY_LOG=info` stream includes draw/pipeline/texture and DXGI budget summaries. If PresentMon is installed or passed through `-PresentMonExe`, the launcher arms an application-frame CSV; press `ALT+SHIFT+F11` after reaching gameplay to start capture and press it again to stop. This lets the operator exclude menus and loading from an exploratory capture. These logs help locate stalls and pressure; they do not by themselves establish a repeated gameplay benchmark. For application-frame FPS, 1%/0.1% lows and frame-time percentiles, use `tools/Measure-AstraForgeGameplay.ps1` with PresentMon and a reproducible scene.

`-CacheDir` and `-DataDir` select external cache and persistent-data directories explicitly. They are useful for pairing a shader-prewarm cohort with exactly one runtime build without copying the cache. The launcher creates missing directories and rejects either path when it is inside the workspace, imported source, or selected application directory. Omitting them keeps the profile-specific defaults under `%LOCALAPPDATA%\VIctory`.

| Profile | Texture room | Intended tradeoff | Evidence |
|---|---:|---|---|
| Stability | 80% | More budget headroom; texture copies may wait longer | Candidate, unmeasured here |
| Balanced | 90% | Source default and closest to the measured 3070 Ti Series S baseline | Candidate, unmeasured here |
| Performance | 85% | Lower copy residency to limit paging; could increase streaming churn | Candidate, unmeasured here |
| Quality | 95% | More room for texture copies; less headroom on an 8 GB card | Candidate, unmeasured here |

The percentages are accepted by the audited source (50–97, default 90); they are not promised FPS settings. They are the only difference among profiles. `VICTORY_DISPLAY_MODE=1920x1080` reports the display mode; the fork's report found no frame-time change from that setting. The source has no separately verified 1280x720 render-scale/upscaler variable. Use the same replay, scene, cache state, and PresentMon capture for each candidate. Do not interpret the labels as measured rankings.

### Static-sampler pipeline library (baseline since 2026-11-27)

The RTX 3070 baseline now sets `VICTORY_LIBRARY_STATIC_SAMPLERS=1`. Without it, the
local NVIDIA bypass adapted from Vice-Tay `fa8fc1d` keeps static-sampler pipelines out of
the host pipeline library, so every launch rebuilds them in the driver. One run logged
94 slow pipelines that took 201 s in total (up to 7.8 s each). Story load then went
more than 30 s without presenting, and the title's own watchdog ended the run. With
the switch set, the library grew from 7 MB to 68 MB. The next launch loaded 1,145
pipelines, built 116, and entered the world without an exception.

Known risk: the driver may restore a stored pipeline with another pipeline's samplers.
That can give a wrong texture filter or address mode, which is a visual risk, not a
stability risk. The correct long-term fix is a sampler table (trustno PR #18,
`VICTORY_PIPELINE_SAMPLER_TABLE`), which is not ported yet. To restore the bypass for
an A/B, pass `-RuntimeOverride @{ VICTORY_LIBRARY_STATIC_SAMPLERS = '0' }`.

### Optional wait experiment

The source also accepts `VICTORY_FILL_TITLE=0`, `1`, or `2`. `0` (and unknown values) keeps the wait; `1` is the existing broader 64 KiB predicate; `2` is the narrower donor predicate, which skips the wait only when no shader write landed in that range during the prior 600 frames. The four supplied profiles do not set this variable. The donor's short A/B result is a hypothesis for this PC, not a guarantee. For a separate comparison, capture the unchanged profile first, then set `VICTORY_FILL_TITLE=2` for a matched run; inspect image correctness, stale constants, device errors, and frametime before considering any preset change. Omit the variable or set `0` to restore the baseline.

The preflight enforces at least 12 GiB of available commit. `-MinimumAvailableCommitGiB` may raise this floor to at most 256 GiB but cannot lower it; there is no low-commit bypass. The launcher rejects missing, negative, NaN, or infinite telemetry. It warns below 20 GiB because a separate 3070 Ti/64 GiB run used about that much in-world, but that is not a prediction for this PC. For a deliberate Series X trial, pass `-Console series-x -AllowSeriesX` and keep the run short while monitoring for paging and device loss; the commit floor remains mandatory.

After the run, inspect `victory.stderr.log`, `memory.csv`, and `gpu-process-counters.csv` in that run's directory. For frame-time percentiles and per-thread/GPU traces use `tools/Measure-AstraForgeGameplay.ps1` with PresentMon and the same `-GpuProfile`, following [the benchmark procedure](benchmark-procedure.md). The public-report exporter emits an allowlisted JSON without local capture/cache paths; inspect it before sharing. The benchmark creates isolated cold caches and clones immutable warm seeds; it never deletes the user's existing cache, saves, or game files.

## Source credit

The baseline environment values and the Series S invocation come from `Play-VIctory.cmd` and `scripts/play-guarded.ps1` in [`grimygunnz/nvidia-3070-VI`](https://github.com/grimygunnz/nvidia-3070-VI), imported at `6e9c1dd9fb32daaa855f446560a4d1f8df5f8424`, descended from the requested COOL_FOX Pareto-residency commit. Current upstream `25ff216` is a docs-only update. The profile-only setting's parser and 50–97 bounds were verified in the imported `crates/victory-gpu/src/resource.rs`. The workspace retains the source's GPL-3.0 license and its local change log lists each code port and its origin.
