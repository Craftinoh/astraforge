# RTX 8 GB runtime variable audit

Runtime-reader audit snapshot: [`grimygunnz/nvidia-3070-VI`](https://github.com/grimygunnz/nvidia-3070-VI/tree/58a0c92acc2a72f7c0d186418c7b9ff8c2bd7d94), commit `58a0c92acc2a72f7c0d186418c7b9ff8c2bd7d94`, descended from the requested `f4b48ad766` Pareto-residency commit. That audit scanned 221 Rust and launcher files. The local source is based on `6e9c1dd9fb32daaa855f446560a4d1f8df5f8424`; current upstream `25ff2168267d967c5e428f94726a7384e59cd5b7` changes only `docs/nvidia-8gb.md`, so the runtime reader inventory remains the same. A lexical scan of the imported source found the same presence/absence set for the 35 requested names. The runtime descriptions below refer to the inspected readers and parser ranges.

## Present in this source tree

These names occur in the source and have runtime readers or launcher use:

`VICTORY_THIN`, `VICTORY_TEXTURE_BUDGET_MB`, `VICTORY_TEXTURE_STAGE_MB`, `VICTORY_TEXTURE_STAGE_MS`, `VICTORY_TEXTURE_NO_WAIT`, `VICTORY_LEVELS_ON_DEMAND`, `VICTORY_UPLOAD_AHEAD`, `VICTORY_AMBIENT`, `VICTORY_AMBIENT_AIR`, `VICTORY_AMBIENT_SHADE`, `VICTORY_PIPELINE_WAIT_MS`, `VICTORY_PIPELINE_WORKERS`, `VICTORY_PIPELINE_LOWEST`, `VICTORY_ASYNC_SUBMIT`, `VICTORY_CARD_BUFFERS_MB`, `VICTORY_CARD_BUFFERS_MIN_KB`, `VICTORY_RELAY`, `VICTORY_WIDE_BACK`, `VICTORY_CARD_STEPS`, `VICTORY_INDIRECT_WINDOW`, `VICTORY_INDIRECT_BATCH`, `VICTORY_JOIN_COPIES`, `VICTORY_JOIN_PARTS`, `VICTORY_MAP_THREADS`.

The 3070 Ti guarded launcher used this Series S set:

```text
VICTORY_AMBIENT_AIR=1.5
VICTORY_TEXTURE_NO_WAIT=1
VICTORY_RELAY=2
VICTORY_WIDE_BACK=1
VICTORY_CARD_REHASH_RUNS=1
VICTORY_JOIN_COPIES=1
VICTORY_INDIRECT_WINDOW=1
VICTORY_RELAY_COPY=1
VICTORY_CARD_STEPS=2
VICTORY_INDIRECT_BATCH=2
VICTORY_MAP_THREADS=1
VICTORY_CARD_AWAKE=1
VICTORY_SHOW_AFTER=1
VICTORY_AMBIENT=0.8
VICTORY_THIN=1
VICTORY_JOIN_PARTS=8
VICTORY_UPLOAD_AHEAD=1
VICTORY_LEVELS_ON_DEMAND=1
VICTORY_CARD_BUFFERS_MIN_KB=64
VICTORY_LOG=info
```

`VICTORY_CARD_BUFFERS_MB` is read by the budget resolver but is not explicitly set by that launcher: the source automatically chooses a 2,048 MiB cap when the process's local DXGI budget is at most 12 GiB. `VICTORY_CARD_PAD_KB` defaults to 64; setting it to zero disables the padding associated with the earlier MMU faults. Keep both defaults for the evidence-based 8 GB starting point. `VICTORY_LEVELS_ON_DEMAND=0` was tested and led to device loss, so it stays enabled.

The source also implements `VICTORY_TEXTURE_ROOM_PERCENT` (integer clamped to 50–97; default 90). It controls the share of the process's local DXGI budget available to texture host copies. The RTX 3070 launcher profiles vary only this control: 80 for Stability, 90 for Balanced, 85 for Performance, and 95 for Quality. These are explicit, reversible candidates, not measured presets. Lowering it can reduce residency pressure but defer texture copies; raising it can increase texture availability but leave less budget headroom. Measure each profile with the same gameplay replay before preferring one.

Other supported names are not part of the measured 3070 Ti launcher: `VICTORY_TEXTURE_BUDGET_MB`, `VICTORY_TEXTURE_STAGE_MB`, `VICTORY_TEXTURE_STAGE_MS`, `VICTORY_PIPELINE_WAIT_MS`, `VICTORY_PIPELINE_WORKERS`, `VICTORY_PIPELINE_LOWEST`, `VICTORY_ASYNC_SUBMIT`, and `VICTORY_AMBIENT_SHADE`. They need individual tests against this machine before entering a gameplay profile. In particular, do not infer the meaning of `VICTORY_TEXTURE_BUDGET_MB` from its name alone: read its `resource.rs` admission path and confirm the resulting memory counters.

O6 source audit detail: when `VICTORY_TEXTURE_STAGE_MB` is explicitly set, `draw.rs` uses it as the per-frame byte ceiling and skips the automatic `residency::prefetch_limit` clamp. The normal dynamic DXGI-room check and `admit_texture_pass` commit reserve still apply, but this override can exceed the automatic 64 MiB limited-RAM/pressure ceiling or 16 MiB critical-pressure ceiling. No supplied 3070 profile sets it; leave it unset until a matched runtime test shows a benefit without increasing staging memory or commit pressure. `VICTORY_TEXTURE_STAGE_MS` similarly controls pass time and is not clamped in the reader, so do not use arbitrarily large values as a general optimization.

The local port of [`fxceless/victory-fork#1044`](https://github.com/fxceless/victory-fork/pull/1044) adds `VICTORY_DSTORAGE_WORKERS` (1–64) as an optional override. When unset, this source now queries Windows for physical cores; on the detected 8c/16t Ryzen 7 7700X it should choose eight workers. The variable is not set in the supplied profiles; its only intended use is controlled A/B measurement.

The imported runtime was audited for the 35 variable names in the request; `VICTORY_DSTORAGE_WORKERS` is a separate addition from the local #1044 port. A valid explicit override is 1 through 64. When unset or invalid, the worker count uses detected physical cores clamped to 1-32; if physical-core detection fails, it uses `max(logical/2, 2)`, also clamped to 1-32. On the detected 8-core / 16-thread Ryzen 7 7700X, the expected default is eight. The supplied profiles leave this variable unset.

## Absent from this source tree

The following names are not present in the scanned Rust or launcher files at this commit; setting them will not provide the behavior they name:

`VICTORY_TEXTURE_DROP_MIPS`, `VICTORY_RENDER_SCALE`, `VICTORY_OWN_UPSCALER`, `VICTORY_COMPOSE`, `VICTORY_NAN_SCRUB`, `VICTORY_AMBIENT_MOST`, `VICTORY_AMBIENT_REFLECT`, `VICTORY_ASYNC_PRESENT`, `VICTORY_COPY_PLAIN`, `VICTORY_SKIP_WC_BACK`, `VICTORY_SKIP_WC_COMPARE`.

The source therefore has no verified independent render-scale/upscaler switch for a 1280x720 render target with 1920x1080 output. The Series S console profile renders its fixed title size; `VICTORY_DISPLAY_MODE=1920x1080` only reports the display mode and did not change the measured frame time. NVIDIA's other forks contain some of the absent switches, but they must not be mixed into this source without implementation, correctness tests, and attribution.

The RTX 3070 launcher does set the supported `VICTORY_DISPLAY_MODE=1920x1080` to report a 1080p display to the title. This is not an internal render-scale control and does not establish a specific upscaler path; the source's Series S render size remains fixed in the cited measurement.

## Launcher and host limits

The upstream guarded script clears inherited `VICTORY_*` environment variables before setting its own list; pass additional values through its `-Set` parameter. Its default 46 GiB process-memory cap came from a 64 GiB host. This RTX 3070 PC has a 38.35 GiB total commit limit, so the 46 GiB cap is unsuitable here. The remote 3070 Ti's measured in-world commit reached about 20 GiB; the latest local capture had 8.32 GiB of commit available, below the local launcher's 12 GiB preflight threshold. Check current headroom before starting and retain continuous monitoring.

The source's host-memory admission code is directly relevant to this 32 GiB machine. `limited_host_ram()` is true at 32 GiB or less. Once staging reaches 1 GiB, that mode caps texture prefetch at 64 MiB per pass; ordinary pressure also caps at 64 MiB, and critical commit pressure caps at 16 MiB. Ordinary upload admission keeps 512 MiB of commit free (256 MiB for a one-shot bake); growing a new staging block keeps 1 GiB free (256 MiB for a bake). Critical pressure starts below 1.5 GiB or for 500 ms after an out-of-memory allocation failure. Pressure enters at 3 GiB free physical memory or 4 GiB available commit, and clears only after both recover to 5 and 6 GiB. This defers texture work and keeps queued slots for later; it is not a hard guarantee against whole-process memory exhaustion. The live 2026-11-26 21:44 capture had 15.49 GiB of available physical memory and 14.95 GiB of available commit; check the current values before each run.

The launcher's exact settings and parser semantics are in [`Play-VIctory.cmd`](https://github.com/grimygunnz/nvidia-3070-VI/blob/58a0c92acc2a72f7c0d186418c7b9ff8c2bd7d94/Play-VIctory.cmd), [`scripts/play-guarded.ps1`](https://github.com/grimygunnz/nvidia-3070-VI/blob/58a0c92acc2a72f7c0d186418c7b9ff8c2bd7d94/scripts/play-guarded.ps1), [`shadow.rs`](https://github.com/grimygunnz/nvidia-3070-VI/blob/58a0c92acc2a72f7c0d186418c7b9ff8c2bd7d94/crates/victory-gpu/src/shadow.rs), [`tiles.rs`](https://github.com/grimygunnz/nvidia-3070-VI/blob/58a0c92acc2a72f7c0d186418c7b9ff8c2bd7d94/crates/victory-gpu/src/tiles.rs), [`resource.rs`](https://github.com/grimygunnz/nvidia-3070-VI/blob/58a0c92acc2a72f7c0d186418c7b9ff8c2bd7d94/crates/victory-gpu/src/resource.rs), and [`pipeline/make.rs`](https://github.com/grimygunnz/nvidia-3070-VI/blob/58a0c92acc2a72f7c0d186418c7b9ff8c2bd7d94/crates/victory-gpu/src/pipeline/make.rs).
