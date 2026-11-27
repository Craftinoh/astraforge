# RTX 3060 observations from Vice-Tay test runs (`host-02`)

These notes come from seven gameplay runs on `host-02` (see [`RTX3060-hardware-report.md`](RTX3060-hardware-report.md)) with the **Vice-Tay** tree, not with AstraForge. They are shared because several findings point at code that AstraForge also carries. None of them is AstraForge performance or compatibility evidence.

## How the runs were made and their limits

- Source: [`TaynanGT/Vice-Tay`](https://github.com/TaynanGT/Vice-Tay) at `877a40e8`, plus local uncommitted changes. How each change is implemented is in [`RTX3060-port-implementation.md`](RTX3060-port-implementation.md). Diagnostic build (`cargo build --profile diag --features diagnostics -p victory`).
- Settings: Vice-Tay `scripts/play.ps1`, Series S target, its `4070` machine preset, windowed, DLSS (Quality in run 1, Performance afterwards), ray tracing off, `VICTORY_D3D12_DRED=0`.
- Frame rates are the runtime's own five-second log reports (frames/s, draws, CPU submission time), filtered to reports with at least 500 draws and no shader compiling. **No PresentMon data.**
- Each setting was run **once**, by a person playing through the story, so the route and scene mix differ between runs. These are not the matched three-run cohorts that [`benchmark-procedure.md`](benchmark-procedure.md) requires. Read the differences as leads, not measured gains.
- Visual statements are the player's own reports during play. No video was recorded or reviewed.
- Scene labels: `scene-01` opening sequence at sea, `scene-02` the following stealth section, `scene-03` later story mission.

## Results by run

| Run | Change from the previous run | Gameplay median fps | Notes |
|---|---|---|---|
| 1 | Baseline, DLSS Quality | 13.2 | |
| 2 | DLSS Performance, plus a busy-wait switch | 15.6 | |
| 3 | DLSS Performance only | 15.4 | 25.4 fps at 500–1,500 draws, 14.5 fps at 5,000–7,000 |
| 4 | Plus a reflection-texel clamp (Vice-Tay `VICTORY_AMBIENT_REFLECT`) | 14.8 | Short run, cold start |
| 5 | Plus the water change (below) | 17.5 | Player: water correct, less flicker |
| 6 | In-run A/B of `VICTORY_ASK_SPREAD` and `VICTORY_LANE_CORE` | — | No difference between phases |
| 7 | Same build as 5 with a warm translation cache and `VICTORY_PIPELINE_BOOK=1` | 16.8 (first ~5 min) | No shader compiling in any report; more flicker, see below |

Run 5 by scene load (frames/s median, CPU submission median, GPU busy median):

| Draws per frame | fps | Submission | GPU busy |
|---|---|---|---|
| 500–1,500 | 26.3 | 34.8 ms | 68% |
| 1,500–3,000 | 20.0 | 45.8 ms | 81% |
| 3,000–5,000 | 17.6 | 51.1 ms | 81% |
| 5,000–7,000 | 15.6 | 57.8 ms | 84% |

The 30 fps goal was not reached. In run 7, 3 of 42 gameplay reports reached about 30 fps, all in light scenes.

## Findings that may matter to AstraForge

1. **The wave-wide form of two water compute programs draws flaring black squares.** Shader hashes `5dc3b25986622949` and `6f225b641c5b0708`. Vice-Tay ships them in a default wave-wide list for 32-lane hosts. Removing them from that list makes them fail translation, so their dispatches are skipped. The player then reported correct-looking water (`scene-01`, `scene-02`). The `fxceless/victory-fork` README (2026-11-27) reports the same symptom and fixes it properly with a paired wave64 translator, about 6,000 lines that were not ported. AstraForge's `emit/mod.rs` leaves the wave-wide form off unless `VICTORY_WAVE_WIDE=1`. That is the safe state; setting `VICTORY_WAVE_WIDE=1` globally on Ampere would likely bring the squares back.
2. **`VICTORY_WAVE_WIDE` is part of the translation-cache key** (`shader_cache.rs`, in both trees). Changing it re-translates every shader, and it also changes how the two 64-thread scene kernels are emitted. Run 5 (0 cache hits, 3,374 misses) and run 7 (3,361 hits, 48 misses) therefore did not use identical shaders, although their environments differed only by the pipeline book. Run 7 brought back extra flicker and worse textures. Treat the cache state as part of any A/B; the procedure's `cold`/`warm` label is not enough when one cache holds translations made under another setting.
3. **The frame rate is limited by the CPU submission thread.** It takes 35 ms per frame in light scenes and 50–76 ms in heavy ones, while the GPU is busy 70–95% of the time. Frame rate falls almost linearly with draws per frame. Vice-Tay's `GetWriteWatch` scans cost about 22 ms per frame over about 8.5 GB of watched ranges. The two scheduling switches tried in run 6 did not reduce it.
4. **About 480 indirect executions are dropped per frame.** In `draw.rs` `execute_indirect`, they fail the same checks as the ray-tracing passes (skipped pipeline, structure builder off, no host pipeline). With ray tracing off, these are expected and are **not** the missing objects below.
5. **Bursts of dynamic-descriptor refusals** occurred: "no free dynamic descriptor slots: a table is not made", n = 21, 178 and 179, once each in separate runs. They happen with the 1,000,000-view NVIDIA heap cap, and the affected draws are skipped for those frames. This may relate to brief flicker; unconfirmed.
6. **Shader stutter is driver pipeline creation, not translation.** Translation-cache misses were 0 to 65 per warm run. Run 7, with a pipeline library built by earlier runs, had no reports with shaders compiling. AstraForge's journal reaches the same conclusion for static-sampler pipelines.

## Open visual issues (player reports, causes unconfirmed)

- Characters inside trailers and some vegetation look missing or unloaded in `scene-03`. Hypotheses: (a) with ray tracing off, anything the sun does not light directly is dark, which the repository docs state; (b) late texture streaming: run 7 logged about 29,000 texture lookups "passed over unmapped". Screenshots are needed to tell these apart.
- Frame-rate swings follow scene load (14–30 fps), as in the tables above.

## What this does not establish

- Any AstraForge frame rate, stability or image quality on the RTX 3060.
- That the copied RTX 3070 tuning values suit a 12 GB card.
- That the water change is correct in every scene. It removes the two dispatches' output instead of translating it, which `AGENTS.md` would not accept as an AstraForge fix ("never remove draws, shader work ...").
