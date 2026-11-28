# Source credits and provenance

This project preserves the upstream GPL-3.0 license and original source notices. See `third_party/nvidia-3070-VI/LICENSE` and `third_party/nvidia-3070-VI/LOCAL-CHANGES.md` for the source checkout and detailed patch ledger.

## Initial source base

- COOL_FOX Pareto-residency, reference commit `f4b48ad766ddbec1a1867022cd42f7645b0dd55e`, associated with `neevets/cool_fox`.
- NVIDIA 8 GB derivative `grimygunnz/nvidia-3070-VI`, imported at `6e9c1dd9fb32daaa855f446560a4d1f8df5f8424`.
- Latest synchronized upstream documentation snapshot: `25ff2168267d967c5e428f94726a7384e59cd5b7`.

## Integrated changes

| Change | Upstream origin | Local source commit | Status |
|---|---|---|---|
| Clippy precedence correction in texture-format code | Current upstream CI finding | `fe8995b` | Behavior-preserving; local compile pending |
| NVIDIA 8 GB documentation sync | `grimygunnz/nvidia-3070-VI` | `2374bca` | Documentation only |
| DirectStorage worker count bounded by physical-core count | fxceless PR #1044 | `f0ab013` | Ported; local build and performance effect unverified |
| Descriptor dynamic-range allocation retains heap identity | fxceless PR #1324 | `878dbd7` | Ported with regression test; local test pending |
| Defer descriptor nulling/resource release while submissions are in flight | `Itsbatt/victory-unified` commit `768735a` | `6e91b7b` | Ported with regression test; workspace tests pass, gameplay stress remains pending |
| Use a neutral default data directory and generic executable name in the copied launcher | Local privacy/documentation change | `afbb784`, `337310f`, `c6f1fc4` | `VICTORY_GAME_DIR` and `VICTORY_GAME_EXE` remain configurable; defaults stay outside the workspace |
| Anonymize title-specific comments and command examples | Local documentation/privacy change | `e31aafd` | Comment-only; runtime behavior unchanged |
| ~~Reserve a null descriptor before the portable heap's dynamic descriptor tail~~ **Reverted 2026-11-27** | Local fix after model-assisted review; no upstream patch copied | `f8b6af5`, reverted in the working tree | Its unit test passed, but the shader clamp then also covered every dynamic descriptor and the output was fully black. Bisection: `a0748dc` renders, `f8b6af5` is black, and the revert renders again |
| Start commit-headroom admission at zero until the first valid Windows sample | Local fail-closed memory-safety change; no upstream patch copied | `42435bf` | Failed initial sampling can defer speculative uploads instead of treating commit headroom as unlimited |
| Correct two indirect-budget regression-test fixtures | Local test-only corrections | `468b79b` | Test inputs and expected accepted work now match the shader's all-or-nothing budget semantics |
| Canonicalize placed-resource padding and unused SRV/UAV union words before shape keying | [`TaynanGT/Vice-Tay#27`](https://github.com/TaynanGT/Vice-Tay/pull/27), focused commits `f07e54a2` and `ce914907`; resource-padding origin also credits `JMAN730/project-flamingo@b1e0cd1d` | `descriptor: canonicalize placed-view shape keys` change set | Two focused tests and all ten descriptor tests pass locally; gameplay memory and rendering remain unverified |
| Add conservative mode `VICTORY_FILL_TITLE=2` for small in-flight memory reads | [`TaynanGT/Vice-Tay@b6be7e3`](https://github.com/TaynanGT/Vice-Tay/commit/b6be7e3b0b2f7ead75ff999ae53e3021da17c7cb) | `32a13f7` | Three predicate tests pass; disabled in all supplied profiles; runtime correctness and A/B effect remain unverified |
| Preserve the first partial title-memory piece when splitting a large shadow comparison across workers | [`TaynanGT/Vice-Tay#114`](https://github.com/TaynanGT/Vice-Tay/pull/114), adapted from [`fxceless/victory-fork#1407`](https://github.com/fxceless/victory-fork/pull/1407), which credits the original finding to Kelvaroq's `stellarr-studio/kelvaroq` patch 0009 | `abcb275` | The regression failed before the fix with debug overflow and passes in debug and Release; no gameplay or FPS effect measured |
| Track decoration-bake coverage per descriptor heap/revision; reject overlapping or truncated scans | [`TaynanGT/Vice-Tay#85`](https://github.com/TaynanGT/Vice-Tay/pull/85), commit `7eef143` (merged 2026-11-27) | Focused local change set `fix: track per-heap texture bake coverage` | Added per-heap/revision and overlap tests plus a truncated-snapshot test; debug diagnostic serial suite and optimized Release suite pass. No gameplay, visual, stability, or FPS effect measured |
| Measure blocking acquisitions of the exact-view cache mutex in the diagnostics build | Local O4 observability change; no upstream patch copied | `f0c57bb` | Collects busy-lock wait duration, maximum, and six bounded buckets only when `diagnostics` is enabled; the Release path has no timer or extra counters. Unit/build results are recorded in the progress journal; no runtime contention or FPS effect measured |
| Correct three shader translation cases: Wave32 collision-register predicate, `v_add_f16` inline constants, and root-constant table offsets | [`TaynanGT/Vice-Tay` merge `708dbfe`](https://github.com/TaynanGT/Vice-Tay/commit/708dbfe7325830d3785846ed24b79e902919a240), PR #229 | `aa875e4` | Focused translation regressions pass; diagnostic build passes. Their individual gameplay and visual effects have not been isolated |
| Scalar operand codes past 127 no longer index past the spill table; `s_min`/`s_max` set SCC from the operand comparison (RDNA 2 ISA) | [`TaynanGT/Vice-Tay` merge `dda5a34`](https://github.com/TaynanGT/Vice-Tay/commit/dda5a34324c2125de28ffd494b49098531d39d6d), PR #315 (commits `00eaf47`, `3c83a33`); ports [trustno1-coder/VIctory-NVIDIA#53](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/53) by illuminatedfellow; reports by 11run11 and simbaui4life | Local focused shader patch, 2026-11-27 | Both new regressions fail without the fix and pass with it; shader suite 285 passed, 4 ignored. The donor `TRANSLATOR_VERSION` bump is not needed because the local translator fingerprint hashes all sources. Gameplay effect not yet established |
| Card-copy sends laid out in one pass; already-ordered, disjoint ranges skip the sort-and-join | [`TaynanGT/Vice-Tay` commit `bb529f1`](https://github.com/TaynanGT/Vice-Tay/commit/bb529f12779f381606dbc93d2e45dd74dc3258b7), PR #286 | Local focused GPU patch, 2026-11-27 | `send.rs` hunks applied unchanged; the `shadow::joined` early return was adapted by hand (the local function has no `len < 2` guard, and `windows(2)` covers it). The `host::send` and `shadow::` tests pass (34 passed, 1 ignored), including the new `one_pass_lays_out_what_three_did` and the extended `ranges_join_where_they_touch`. Gameplay effect not yet measured |
| Before each decoration (skin) bake, every source slot its constants and records name is checked; stale views, missing host copies and host copies holding other bytes are uploaded on the bake's own synchronous list regardless of room or pass budget (`VICTORY_BAKE_SOURCES=0` restores the old behaviour) | [`fxceless/victory-fork`](https://github.com/fxceless/victory-fork) commits [`b3d49db`](https://github.com/fxceless/victory-fork/commit/b3d49db34fb30d1146931901ee7d5ab15dca4ba3), [`082ebaf`](https://github.com/fxceless/victory-fork/commit/082ebaf3b8aad83c2db200c5ba10782db5c1f545), [`2983a71`](https://github.com/fxceless/victory-fork/commit/2983a71161e8d5320ea9e453dcb5d283ff257384), authored by readmet3xt-lab; the 4 GB report linking black skin to missing host copies is from `Dathinel/victory-4gb` | Local focused GPU patch, 2026-11-27 | Two hunks were resolved by hand: the counters were inserted beside the local `BAKE_UPLOAD` code, and the source check runs after the per-heap coverage pass from Vice-Tay #85. Two timing-instrumentation hunks of `082ebaf` that depend on a donor-only `HEAP_TEXTURE_MICROS` were left out. GPU library tests pass (352 passed, 34 ignored). Three automated release runs at 720p each logged about 180 stale skin sources brought up to date before baking, with 0 failures and internal 10.1–11.6 fps (baseline runs 9.4–10.6). In three diagnostic runs, skin was still black in one, so this fixes one cause of intermittent black skin but not all of them |
| New texture blocks only within the texture line; the idle-texture sweep follows that line (`VICTORY_POOL_GATE=0` restores the old rule) | [`fxceless/victory-fork@2eade68c`](https://github.com/fxceless/victory-fork/commit/2eade68c) | Local adapted GPU patch, 2026-11-27 | `pool.rs` applied unchanged. `room_line` and `vram_keep_below` were added locally, and the slot hold uses the local `texture_slot_held`. Log lines and the ray-tracing arena rule were omitted. Tests: 356 passed, 34 ignored. One 4-minute session held VRAM at 6.21–6.26 of 7.0 GB, with no crash and 9.9 fps internal. A long-session effect is not yet measured |
| Bypass persistent pipeline-library reuse for NVIDIA PSOs with static samplers unless explicitly enabled | [`TaynanGT/Vice-Tay` commit `fa8fc1d`](https://github.com/TaynanGT/Vice-Tay/commit/fa8fc1d4691910642d8b487571eaf040aa062c21), “Correct Direct3D 12 bindings and NVIDIA pipeline reuse” | `45ba21d` | Host pipeline tests and the diagnostic build pass. `VICTORY_LIBRARY_STATIC_SAMPLERS=1` selects reuse; its individual gameplay and visual effects have not been isolated |
| Write-combined title memory: shader writes into copies of memory the title asked for as write-combined (protection 0x400) are not copied back into title memory (`VICTORY_WC_NO_BACK=1`), except for copies under `VICTORY_WC_NO_BACK_MIN_KB` | [`trustno1-coder/VIctory-NVIDIA@50c15a14`](https://github.com/trustno1-coder/VIctory-NVIDIA/commit/50c15a14) and [`@2f81d0c8`](https://github.com/trustno1-coder/VIctory-NVIDIA/commit/2f81d0c8); the same switch is used by `crossducking/RAZDA4A-XEN` | Local port, 2026-11-28; the test hunk was re-placed by hand | victory-gpu lib 358 passed. Three interleaved run pairs at 64 KiB: copy-back about 21 MB a frame against 33.5 MB; time and fps within noise; no new visual defect seen by the user. With no minimum, faces went wrong in play |
| BCPack BC7: the rotation field only in modes 4 and 5; other modes kept their channel precisions and p-bit | [`trustno1-coder/VIctory-NVIDIA@6726920a`](https://github.com/trustno1-coder/VIctory-NVIDIA/commit/6726920a), original by fxceless (`06702fe8`, after upstream VIctory #3111) | Applied cleanly 2026-11-28 | victory-formats lib 42 passed, including the donor test |
| At most a million table entries for placed views no resource releases (long-session memory) | [`trustno1-coder/VIctory-NVIDIA@89fd9361`](https://github.com/trustno1-coder/VIctory-NVIDIA/commit/89fd9361) | Applied cleanly 2026-11-28 | victory-gpu lib 365 passed |
| Memory by address: after a failed arena, none is tried again before the next frame; arena room reserved at start (structure builder) | [`trustno1-coder/VIctory-NVIDIA@30b979ee`](https://github.com/trustno1-coder/VIctory-NVIDIA/commit/30b979ee) | Applied cleanly 2026-11-28 | victory-gpu lib 365 passed |
| Raw buffer views stay inside their buffer (`VICTORY_RAW_VIEW_CLAMP`, on; `=0` restores) | [`trustno1-coder/VIctory-NVIDIA@aec85efb`](https://github.com/trustno1-coder/VIctory-NVIDIA/commit/aec85efb), original by lichenlang89 (fxceless/victory-fork #1266, `dd5e8c9e`) | Ported 2026-11-28; the switch and the meter-line counters placed by hand | victory-gpu lib 365 passed |
| Ambient stand-in drops violet and magenta probe leftovers before the raise | [`trustno1-coder/VIctory-NVIDIA@826ba150`](https://github.com/trustno1-coder/VIctory-NVIDIA/commit/826ba150), after VIctory-Belobug-AMD | Ported by hand 2026-11-28 (shader text context differed) | victory-gpu lib 365 passed |
| The render-target reserve of the texture queue is given up once targets hold half of it and have not grown by 64 MiB for 20 s (`VICTORY_CARD_ROOM_FOR_TARGETS_SETTLE_MS`); the texture line logs its terms | [`trustno1-coder/VIctory-NVIDIA@21b040da`](https://github.com/trustno1-coder/VIctory-NVIDIA/commit/21b040da) | `b0c5667`; one timing-counter line placed by hand | GPU library tests passed. A 1,536 MB profile override caused severe residency stalls and was removed; the prior reserve remains |
| Read BC7 dictionary indices from their first word in BCPack blocks | Local correction; no external source copied | `e8da3b1` | BC7 reference streams match byte for byte in 53 cases, alongside BC6H and BC1/3/4/5 comparisons. Individual gameplay effect unisolated |
| Place a texture in the free range of its block that leaves the least space behind | Local placement change; no external source copied | `6757501` | GPU library tests pass; one 120-second diagnostic comparison is inconclusive. `VICTORY_POOL_BEST_FIT=0` restores the earlier placement |

## Reviewed, not merged wholesale

The comparison report records the relevant fixes and measured evidence from the NVIDIA-focused fork, `victory-unified`, the 8 GB NVIDIA fork, the 7900 XTX fork, the fxceless fork, and the shader-lab work. Only changes with a clear source match and a plausible correctness/performance case are candidates for integration. Each imported change must retain its origin and pass the local build and validation path before it is described as verified.

## Broader lineage acknowledgements

The following acknowledgements summarize the lineage published by
[`TaynanGT/Vice-Tay`](https://github.com/TaynanGT/Vice-Tay). They recognize the projects
and contributors in that upstream history; they do not claim that every listed change
is present in the AstraForge source snapshot. Exact AstraForge imports remain the
itemized rows above and the subtree `LOCAL-CHANGES.md`. The upstream repository retains
its full contributor history and credits.

- [`Marvisak/VIctory`](https://github.com/Marvisak/VIctory) and its contributors built
  the loader, console runtime, Direct3D 12 backend, and shader recompiler.
- [`fxceless/victory-fork`](https://github.com/fxceless/victory-fork) and its
  contributors provided fork history used by Vice-Tay.
- [`avatarmanz/VIctory-7900XTX`](https://github.com/avatarmanz/VIctory-7900XTX)
  contributed parallel command recording and translation, accelerated submissions,
  copy-queue texture uploads, and frame replay.
- [`codec-d/cool_fox`](https://github.com/neevets/cool_fox) contributed two-plane
  composition, fallback heaps, descriptor-table plans, residency and fence handling,
  NVIDIA Wave32 lowering, movie uploads, and XMA audio fixes.
- [`DexNom/VIctory`](https://github.com/DexNom/VIctory) contributed ray-tracing fixes,
  cube gradients, and sparse textures.
- [`Belobug/VIctory-Belobug-AMD`](https://github.com/Belobug/VIctory-Belobug-AMD)
  contributed the overlay, ambient-lighting work, and pipeline workers, including work
  by `romainhedouin`.
- [`FQY55kai/ZJOU-VICTORY`](https://github.com/FQY55kai/ZJOU-VICTORY) and
  [`myokex/victory-amd`](https://github.com/myokex/victory-amd) are part of the lineage.
  The latter includes page-view and title-memory work by `Spexivus`, `joroyt`,
  `tightfall`, and `Joshua Odom`.
- `Geckomacabre` and `cxy0072019-sketch` contributed texture read-back. `meshahid973`,
  `nullexxx`, `cxy0072019-sketch`, and `welisonzika14-jpg` contributed fixes and reviews
  through Vice-Tay pull requests.
- [`ivall/XCL`](https://github.com/ivall/XCL), licensed GPL-2.0-only, served as a
  behavioral reference in that lineage. This acknowledgement does not record an XCL
  source import into AstraForge.

## Publication policy

Keep the original GPL-3.0 license, copyright headers, and notices. Do not upload game data, executable images, keys, saves, shader caches, private logs, or raw hardware reports. Public benchmark material must use anonymous scenario aliases and omit title/executable/path identifiers. Do not describe this project as endorsed by any upstream developer or GPU vendor.
