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
| Correct three shader translation cases: Wave32 collision-register predicate, `v_add_f16` inline constants, and root-constant table offsets | [`TaynanGT/Vice-Tay` merge `708dbfe`](https://github.com/TaynanGT/Vice-Tay/commit/708dbfe7325830d3785846ed24b79e902919a240), PR #229 | Current uncommitted shader patch | Focused translation regressions pass; diagnostic build passes. These fixes remove specific translation errors; their effect on the observed black output and gameplay is not yet established |
| Scalar operand codes past 127 no longer index past the spill table; `s_min`/`s_max` set SCC from the operand comparison (RDNA 2 ISA) | [`TaynanGT/Vice-Tay` merge `dda5a34`](https://github.com/TaynanGT/Vice-Tay/commit/dda5a34324c2125de28ffd494b49098531d39d6d), PR #315 (commits `00eaf47`, `3c83a33`); ports [trustno1-coder/VIctory-NVIDIA#53](https://github.com/trustno1-coder/VIctory-NVIDIA/pull/53) by illuminatedfellow; reports by 11run11 and simbaui4life | Local focused shader patch, 2026-11-27 | Both new regressions fail without the fix and pass with it; shader suite 285 passed, 4 ignored. The donor `TRANSLATOR_VERSION` bump is not needed because the local translator fingerprint hashes all sources. Gameplay effect not yet established |
| Card-copy sends laid out in one pass; already-ordered, disjoint ranges skip the sort-and-join | [`TaynanGT/Vice-Tay` commit `bb529f1`](https://github.com/TaynanGT/Vice-Tay/commit/bb529f12779f381606dbc93d2e45dd74dc3258b7), PR #286 | Local focused GPU patch, 2026-11-27 | `send.rs` hunks applied unchanged; the `shadow::joined` early return was adapted by hand (the local function has no `len < 2` guard, and `windows(2)` covers it). The `host::send` and `shadow::` tests pass (34 passed, 1 ignored), including the new `one_pass_lays_out_what_three_did` and the extended `ranges_join_where_they_touch`. Gameplay effect not yet measured |
| Bypass persistent pipeline-library reuse for NVIDIA PSOs with static samplers unless explicitly enabled | [`TaynanGT/Vice-Tay` commit `fa8fc1d`](https://github.com/TaynanGT/Vice-Tay/commit/fa8fc1d4691910642d8b487571eaf040aa062c21), “Correct Direct3D 12 bindings and NVIDIA pipeline reuse” | Current uncommitted GPU patch | Host pipeline tests and the diagnostic build pass. `VICTORY_LIBRARY_STATIC_SAMPLERS=1` is an opt-in A/B override; no gameplay or visual result yet |

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
